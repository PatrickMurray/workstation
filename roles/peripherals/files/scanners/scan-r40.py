#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#   "img2pdf==0.6.3",
#   "numpy==2.5.3",
#   "opencv-python-headless==5.0.0.93",
#   "pillow==12.3.0",
#   "python-sane==2.9.2",
# ]
# ///
"""Scan documents from a Canon imageFORMULA R40 into a PDF or TIFF.

The SANE canon_dr backend returns the front side of each sheet mirrored
horizontally (the back side is correct), and Document Scanner exposes
neither duplex reliably nor the backend's software crop. This script drives
the backend directly, un-mirrors front sides using the backend's per-page
`side` option, locates each sheet against the scanner backdrop to straighten
and crop it, and assembles the pages into a single PDF or multi-page TIFF.
PDFs are given a searchable text layer via OCRmyPDF (Tesseract), which also
turns sideways or upside-down pages upright, leaving the scanned images
untouched.

Profiles (the R40's optical maximum is 600dpi; higher is interpolation):
  pdf   300dpi color, JPEG q90 (compact, visually near-identical)
  tiff  600dpi color, LZW (lossless, archival)
"""

import argparse
import io
import math
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

import cv2
import img2pdf
import numpy as np
import sane
from PIL import Image, ImageOps

NO_DOCS = "Document feeder out of documents"
SIDE_FRONT = 0
# The default scan area is exactly letter height, but capture begins slightly
# ahead of the leading edge, cutting off the bottom of letter sheets. Scan a
# legal-length area instead; the R40 fills rows past the trailing edge with
# backdrop color, which crop_page removes.
PAGE_HEIGHT_MM = 355.6
# The default scan width is exactly letter width, so any skew pushes a letter
# sheet's corners out of frame; use the R40's full width for some clearance
PAGE_WIDTH_MM = 219.4
# The backend's swcrop/swdeskew misjudge the R40's light backdrop, leaving the
# full frame or cutting into near-blank pages, so the sheet is located here
# instead: whatever differs from the backdrop, measured on a slightly blurred
# image to ignore sensor noise. Paper reads darker toward the sides of the
# frame (~247 against ~254 centered), so the light tolerance is kept tight;
# imaged backdrop beside the sheet varies more on the dark side.
BACKDROP_LEVEL = 238
LIGHT_TOLERANCE = 4
DARK_TOLERANCE = 16
# The sheet casts a shadow up to ~0.05in deep along its edges, as dark as
# printed content at the trailing edge; a dark band at an edge no deeper than
# this is shadow and trimmed, a deeper one is content (e.g. a full-bleed
# stripe) and kept
SHADOW_MAX_INCHES = 0.07
BLUR_INCHES = 0.007
# Gaps in the sheet's outline (dark content at the edge) are closed, specks of
# noise on the backdrop are dropped
CLOSE_INCHES = 0.1
OPEN_INCHES = 0.02
# Smallest outline taken for a sheet; anything smaller leaves the page uncropped
MIN_SHEET_SQUARE_INCHES = 1.0
MIN_SHEET_SIDE_INCHES = 0.5
# Skew is measured along each of the sheet's edges that is fully imaged:
# edges may run out of frame (the back side's leading edge often starts above
# it), and where the sheet ends early the R40 cuts it off with a straight line
# of uniform fill. Edge points further than the tolerance from the fitted line
# (dark content at the edge, torn corners) are ignored, and an edge with too
# few points on its line, or too short, is not used.
EDGE_FIT_TOLERANCE_INCHES = 0.01
MIN_EDGE_INCHES = 0.5
MAX_CLIPPED_FRACTION = 0.2
# Edge points this close to the frame border or fill count as clipped (the
# rows where the sheet meets the fill blend the two)
CLIP_MARGIN_INCHES = 0.02
# Max brightness spread within a row of the R40's fill past the trailing edge
FILL_SPREAD = 4
# Skews below this are cropped without resampling the image
MIN_SKEW_DEGREES = 0.05
# Once straightened, the crop is shrunk until each edge line is this much paper
SOLID_COVERAGE = 0.995
# Inset past the detected outline, removing the blurred paper edge
EDGE_MARGIN_INCHES = 0.01


@dataclass(frozen=True)
class Profile:
    extension: str
    mode: str
    resolution: int


PROFILES = {
    "pdf": Profile(extension="pdf", mode="Color", resolution=300),
    "tiff": Profile(extension="tif", mode="Color", resolution=600),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="scan-r40",
        description="Scan from a Canon imageFORMULA R40 into a PDF or TIFF.",
    )
    parser.add_argument(
        "-p",
        "--profile",
        choices=PROFILES,
        default="pdf",
        help="pdf (compact JPEG PDF) or tiff (lossless TIFF). Default: pdf.",
    )
    parser.add_argument(
        "-s",
        "--simplex",
        action="store_true",
        help="Single-sided (front only). Default is double-sided.",
    )
    parser.add_argument(
        "-m",
        "--mode",
        choices=["Color", "Gray", "Lineart"],
        help="Override the profile's scan mode.",
    )
    parser.add_argument(
        "-r",
        "--resolution",
        type=int,
        choices=[150, 200, 300, 600],
        help="Override the profile's resolution (dpi).",
    )
    parser.add_argument(
        "-b",
        "--skip-blank",
        type=float,
        nargs="?",
        const=1.0,
        metavar="PCT",
        help="Discard pages with fewer than PCT%% dark pixels (default 1.0).",
    )
    parser.add_argument(
        "--disable-ocr",
        action="store_true",
        help="Skip adding a searchable text layer to the PDF.",
    )
    parser.add_argument(
        "-l",
        "--language",
        default="eng",
        help="Tesseract OCR language(s), e.g. eng+deu. Default: eng.",
    )
    parser.add_argument(
        "--keep-raw",
        type=Path,
        metavar="DIR",
        help="Also save the uncropped scans to DIR/<output name>/, for troubleshooting.",
    )
    parser.add_argument(
        "output",
        nargs="?",
        type=Path,
        help="Output file. Default: ~/Documents/Scans/scan-YYYYMMDD-HHMMSS.{pdf,tif}",
    )
    return parser.parse_args()


def find_device() -> str:
    for name, _vendor, model, _type in sane.get_devices(localOnly=True):
        if name.startswith("canon_dr:") and "R40" in model:
            return name
    sys.exit("scan-r40: R40 not found. Is it connected and Auto Start off?")


def sheet_mask(image: Image.Image, resolution: int) -> np.ndarray | None:
    """Solid mask of the sheet: the largest region unlike the backdrop."""

    def pixels(inches: float) -> int:
        return max(1, round(inches * resolution))

    gray = cv2.GaussianBlur(np.asarray(image.convert("L")), (0, 0), pixels(BLUR_INCHES))
    mask = np.where(
        (gray > BACKDROP_LEVEL + LIGHT_TOLERANCE)
        | (gray < BACKDROP_LEVEL - DARK_TOLERANCE),
        255,
        0,
    ).astype(np.uint8)
    # Pad with background: by default, OpenCV treats beyond the frame as
    # foreground when eroding, so closing would join the sheet to the frame
    # border across the backdrop and shadow between them
    pad = pixels(CLOSE_INCHES)
    mask = cv2.copyMakeBorder(mask, pad, pad, pad, pad, cv2.BORDER_CONSTANT, value=0)
    for operation, inches in (
        (cv2.MORPH_OPEN, OPEN_INCHES),
        (cv2.MORPH_CLOSE, CLOSE_INCHES),
    ):
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (pixels(inches),) * 2)
        mask = cv2.morphologyEx(mask, operation, kernel)

    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    outline = max(contours, key=cv2.contourArea, default=None)
    if (
        outline is None
        or cv2.contourArea(outline) < MIN_SHEET_SQUARE_INCHES * resolution**2
    ):
        return None
    # Filled outline, so dark content inside the sheet leaves no holes
    sheet = np.zeros_like(mask)
    cv2.drawContours(sheet, [outline], -1, 255, cv2.FILLED)
    return sheet[pad:-pad, pad:-pad]


def fill_start(gray: np.ndarray) -> int:
    """First row of the uniform fill the R40 adds past the trailing edge."""
    uniform = (gray.max(axis=1).astype(int) - gray.min(axis=1)) <= FILL_SPREAD
    # Rows from the bottom up while uniform
    return len(uniform) - int(np.argmin(uniform[::-1])) if not uniform.all() else 0


def edge_skew(
    profile: np.ndarray, positions: np.ndarray, resolution: int
) -> tuple[float, int]:
    """Slope of an edge profile, and the number of points on the fitted line."""
    tolerance = max(1.0, EDGE_FIT_TOLERANCE_INCHES * resolution)
    keep = np.ones(len(positions), dtype=bool)
    for _ in range(3):
        slope, intercept = np.polyfit(positions[keep], profile[keep], 1)
        fitted = np.abs(profile - (slope * positions + intercept)) <= tolerance
        if fitted.sum() < len(positions) // 2:
            break
        keep = fitted
    return float(slope), int(keep.sum())


def sheet_skew(sheet: np.ndarray, fill: int, resolution: int) -> float:
    """Skew of the sheet in degrees (positive: top edge falls to the right)."""
    # Rows from the fill onward are frame, as the sheet's outline there is a cut
    if fill:
        sheet = sheet[:fill]
    # Each edge viewed as the top edge of a flipped or transposed mask, with
    # the sign mapping its slope to the sheet's skew
    views = {
        "top": (sheet, 1),
        "bottom": (sheet[::-1], -1),
        "left": (sheet.T, -1),
        "right": (sheet.T[::-1], 1),
    }
    skews, weights = [], []
    for view, sign in views.values():
        positions = np.flatnonzero(view.any(axis=0))
        if len(positions) == 0:
            continue
        # Middle 80% of the edge, clear of rounded or torn corners
        span = positions[-1] - positions[0]
        positions = np.arange(positions[0] + span // 10, positions[-1] - span // 10 + 1)
        if len(positions) < MIN_EDGE_INCHES * resolution:
            continue
        profile = view[:, positions].argmax(axis=0)
        # Points on the frame border are where the sheet runs out of frame
        clipped = profile <= CLIP_MARGIN_INCHES * resolution
        if clipped.mean() > MAX_CLIPPED_FRACTION:
            continue
        slope, fitted = edge_skew(profile, positions, resolution)
        if fitted < len(positions) // 2:
            continue
        skews.append(sign * math.degrees(math.atan(slope)))
        weights.append(fitted)
    if not skews:
        return 0.0

    # Weighted median, robust to an edge that is bent or partly out of frame
    order = np.argsort(skews)
    cumulative = np.cumsum(np.array(weights)[order])
    return float(
        np.array(skews)[order][np.searchsorted(cumulative, cumulative[-1] / 2)]
    )


def solid_bounds(sheet: np.ndarray) -> tuple[int, int, int, int]:
    """Largest box within the sheet's bounds whose edges are all solid paper."""
    rows = np.flatnonzero(sheet.any(axis=1))
    columns = np.flatnonzero(sheet.any(axis=0))
    top, bottom = int(rows[0]), int(rows[-1]) + 1
    left, right = int(columns[0]), int(columns[-1]) + 1
    # Trim the least solid edge first: trimming a fixed edge first would eat
    # into the sheet wherever another edge is the one overhanging it
    while bottom - top > 1 and right - left > 1:
        coverage = {
            "top": sheet[top, left:right].mean(),
            "bottom": sheet[bottom - 1, left:right].mean(),
            "left": sheet[top:bottom, left].mean(),
            "right": sheet[top:bottom, right - 1].mean(),
        }
        edge = min(coverage, key=coverage.get)
        if coverage[edge] >= 255 * SOLID_COVERAGE:
            break
        if edge == "top":
            top += 1
        elif edge == "bottom":
            bottom -= 1
        elif edge == "left":
            left += 1
        else:
            right -= 1
    return left, top, right, bottom


def shadow_bounds(
    image: Image.Image, bounds: tuple[int, int, int, int], resolution: int
) -> tuple[int, int, int, int]:
    """Bounds inset past thin dark bands (shadow) at each edge."""
    left, top, right, bottom = bounds
    gray = np.asarray(image.convert("L"))[top:bottom, left:right]
    dark = BACKDROP_LEVEL - DARK_TOLERANCE
    limit = round(SHADOW_MAX_INCHES * resolution)

    def depth(means: np.ndarray) -> int:
        """Lines to trim: through the last dark line near the edge, if thin."""
        # Blurring when masking spreads the shadow onto the backdrop beside
        # it, so the outermost lines may be backdrop rather than dark
        near = np.flatnonzero(means[:limit] < dark)
        if len(near) == 0:
            return 0
        if len(means) <= limit or means[limit] < dark:
            # Deep dark content: trim only the backdrop outside it (any
            # shadow beyond it is indistinguishable from the content)
            return int(near[0])
        return int(near[-1]) + 1

    # Medians, so content crossing a line (e.g. a stripe along the adjacent
    # edge) doesn't make the shadow beside it look deep
    rows, columns = np.median(gray, axis=1), np.median(gray, axis=0)
    return (
        left + depth(columns),
        top + depth(rows),
        right - depth(columns[::-1]),
        bottom - depth(rows[::-1]),
    )


def crop_page(image: Image.Image, resolution: int) -> Image.Image:
    """Straighten and crop a scan to the sheet, removing the backdrop."""
    bilevel = image.mode == "1"
    if bilevel:
        image = image.convert("L")

    sheet = sheet_mask(image, resolution)
    if sheet is None:
        print("scan-r40: sheet not found, page left uncropped", file=sys.stderr)
    else:
        uncropped = image
        fill = fill_start(np.asarray(image.convert("L")))
        skew = sheet_skew(sheet, fill, resolution)
        if abs(skew) >= MIN_SKEW_DEGREES:
            # Rotating counter-clockwise by the skew levels the top edge
            height, width = sheet.shape
            rotation = cv2.getRotationMatrix2D((width / 2, height / 2), skew, 1.0)
            image = Image.fromarray(
                cv2.warpAffine(
                    np.asarray(image),
                    rotation,
                    (width, height),
                    flags=cv2.INTER_CUBIC,
                    borderMode=cv2.BORDER_REPLICATE,
                )
            )
            sheet = cv2.warpAffine(
                sheet, rotation, (width, height), flags=cv2.INTER_NEAREST
            )

        left, top, right, bottom = shadow_bounds(image, solid_bounds(sheet), resolution)
        margin = max(1, round(EDGE_MARGIN_INCHES * resolution))
        width, height = right - left - 2 * margin, bottom - top - 2 * margin
        if min(width, height) < MIN_SHEET_SIDE_INCHES * resolution or (
            width * height < MIN_SHEET_SQUARE_INCHES * resolution**2
        ):
            print(
                f"scan-r40: implausible crop ({width}x{height}px at {skew:.2f} degrees),"
                " page left uncropped",
                file=sys.stderr,
            )
            image = uncropped
        else:
            image = image.crop(
                (left + margin, top + margin, right - margin, bottom - margin)
            )

    return image.convert("1", dither=Image.Dither.NONE) if bilevel else image


def scan(
    device: sane.SaneDev, workdir: Path, resolution: int, raw: Path | None
) -> list[Path]:
    """Scan every sheet in the feeder, writing cropped pages to workdir."""
    pages = []
    while True:
        try:
            device.start()
        except sane._sane.error as e:
            if str(e) == NO_DOCS:
                break
            raise
        # Side of the frame the next read returns; skipped blanks never surface
        side = device.side
        image = device.snap(no_cancel=True)
        if side == SIDE_FRONT:
            image = ImageOps.mirror(image)
        page = workdir / f"page-{len(pages):04d}.png"
        if raw is not None:
            image.save(raw / page.name, compress_level=1)
        image = crop_page(image, resolution)
        image.save(page, compress_level=1)
        pages.append(page)
        print(f"scan-r40: scanned page {len(pages)}", file=sys.stderr)
    return pages


def write_pdf(pages: list[Path], output: Path, resolution: int, mode: str) -> None:
    def encode(page: Path) -> bytes:
        buffer = io.BytesIO()
        with Image.open(page) as image:
            if mode == "Lineart":
                # Bilevel pages are embedded losslessly; JPEG only adds artifacts
                image.convert("1").save(
                    buffer,
                    format="PNG",
                    dpi=(resolution, resolution),
                )
            else:
                image.save(
                    buffer,
                    format="JPEG",
                    quality=90,
                    dpi=(resolution, resolution),
                )
        return buffer.getvalue()

    # img2pdf embeds the JPEG/PNG streams as-is, without re-encoding
    output.write_bytes(img2pdf.convert([encode(page) for page in pages]))


def ocr_pdf(source: Path, output: Path, language: str) -> None:
    # Plain PDF output and no optimization keep the scanned images byte-for-byte
    # and avoid a Ghostscript PDF/A rewrite; only the text layer is added
    result = subprocess.run(
        [
            "ocrmypdf",
            "--output-type",
            "pdf",
            "--optimize",
            "0",
            # Orientation is set via the page's /Rotate entry, not re-encoding
            "--rotate-pages",
            "--language",
            language,
            str(source),
            str(output),
        ],
        # Failure is handled below by saving the PDF without a text layer
        check=False,
    )
    if result.returncode != 0:
        shutil.copyfile(source, output)
        print(
            f"scan-r40: OCR failed (exit {result.returncode}), saved without text layer",
            file=sys.stderr,
        )


def write_tiff(pages: list[Path], output: Path, resolution: int) -> None:
    first, *rest = (Image.open(page) for page in pages)
    first.save(
        output,
        format="TIFF",
        save_all=True,
        append_images=rest,
        compression="tiff_lzw",
        dpi=(resolution, resolution),
    )


def main() -> None:
    args = parse_args()
    profile = PROFILES[args.profile]
    mode = args.mode or profile.mode
    resolution = args.resolution or profile.resolution

    output = args.output or (
        Path.home()
        / "Documents"
        / "Scans"
        / f"scan-{datetime.now().astimezone():%Y%m%d-%H%M%S}.{profile.extension}"
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    # A folder per scan, so successive scans don't overwrite each other's pages
    raw = args.keep_raw / output.stem if args.keep_raw is not None else None
    if raw is not None:
        raw.mkdir(parents=True, exist_ok=True)

    sane.init()
    try:
        name = find_device()
        try:
            device = sane.open(name)
        except sane._sane.error as e:
            sys.exit(f"scan-r40: cannot open R40 ({e}). Is another app using it?")

        try:
            device.source = "ADF Front" if args.simplex else "ADF Duplex"
            device.mode = mode
            device.resolution = resolution
            # Page height bounds the scan area, so it must be raised first
            device.page_height = PAGE_HEIGHT_MM
            device.br_y = PAGE_HEIGHT_MM
            device.page_width = PAGE_WIDTH_MM
            device.br_x = PAGE_WIDTH_MM
            if args.skip_blank is not None:
                device.swskip = args.skip_blank

            with tempfile.TemporaryDirectory(prefix="scan-r40-") as tmp:
                pages = scan(device, Path(tmp), resolution, raw)
                if not pages:
                    sys.exit(
                        "scan-r40: no pages scanned. Is paper loaded in the feeder?"
                    )

                if args.profile == "pdf" and args.disable_ocr:
                    write_pdf(pages, output, resolution, mode)
                elif args.profile == "pdf":
                    unsearchable = Path(tmp) / "scan.pdf"
                    write_pdf(pages, unsearchable, resolution, mode)
                    ocr_pdf(unsearchable, output, args.language)
                else:
                    write_tiff(pages, output, resolution)
        finally:
            device.cancel()
            device.close()
    finally:
        sane.exit()

    print(f"scan-r40: {len(pages)} page(s) saved to {output}")


if __name__ == "__main__":
    main()
