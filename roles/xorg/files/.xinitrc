if [ -f ~/.Xresources ]; then
	xrdb -merge -I $HOME ~/.Xresources
fi


xrandr                \
  --output  "LVDS-1"  \
  --mode    "1366x768"

xrandr                   \
  --output  "VGA-1"      \
  --mode    "1920x1080"  \
  --rotate  "right"


xrandr                 \
  --output  "DP-2"     \
  --mode    "3840x2160"


xset -b

xsetroot                   \
  -solid        "#222d82"  \
  -cursor_name  left_ptr


unclutter &


exec i3

