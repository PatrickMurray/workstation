# YubiKey

SSH authentication and git commit signing use a FIDO2 key on a connected
YubiKey (FIDO2 PIN + touch). Workstations without an enrolled YubiKey fall back
to the passphrase-protected workstation key. Enrolled YubiKeys are listed in
[yubikeys.yml](../yubikeys.yml) and deployed to every workstation.

## How It Works

- **SSH:** `~/.ssh/config.d/yubikeys.conf` offers the key of whichever enrolled
  YubiKey is connected (matched by serial number), ahead of the workstation
  key.
- **Commit signing:** git signs with SSH keys (`gpg.format=ssh`) via
  `~/.local/bin/git-ssh-sign`, which swaps in the connected YubiKey's key, or
  uses the workstation key when none is connected.
- **Verification:** `~/.ssh/allowed_signers` lists every key, so
  `git log --show-signature` verifies commits locally.

The SSH configuration (`roles/system_administration/files/ssh/config`) must
begin with `Include config.d/*.conf` so the YubiKey identities are offered
before the workstation key.

## Enroll a YubiKey

1. Set a FIDO2 PIN, if one is not already set:

   ```bash
   ykman fido access change-pin
   ```

2. Note the YubiKey's serial number:

   ```bash
   ykman list --serials
   ```

3. Generate a key handle, replacing `SERIAL` with the serial number and `DATE`
   with today's date (`YYYY-MM-DD`). Enter the FIDO2 PIN and touch the YubiKey
   when prompted, then press Enter at both passphrase prompts. The PIN and touch
   protect the key, and the handle is useless without the YubiKey:

   ```bash
   ssh-keygen  \
     -t ed25519-sk  \
     -O verify-required  \
     -f ~/.ssh/id-ed25519-sk-yubikey-SERIAL-DATE  \
     -C "yubikey-SERIAL-DATE";
   ```

   Name the key after the YubiKey, not a computer, since every workstation
   receives every key. The date keeps a re-enrolled YubiKey's new key distinct
   from its old one.

4. Copy the key handle and public key into the repository, encrypting both:

   ```bash
   cp ~/.ssh/id-ed25519-sk-yubikey-SERIAL-DATE* roles/system_administration/files/ssh/
   ansible-vault encrypt roles/system_administration/files/ssh/id-ed25519-sk-yubikey-SERIAL-DATE
   ansible-vault encrypt roles/system_administration/files/ssh/id-ed25519-sk-yubikey-SERIAL-DATE.pub
   ```

5. Add an entry to [yubikeys.yml](../yubikeys.yml):

   ```yaml
   yubikeys:
     - name: yubikey-zbook
       serial: SERIAL
       ssh_key: id-ed25519-sk-yubikey-SERIAL-DATE
   ```

   `name` is a free-form label, e.g. the computer the YubiKey usually lives
   with.

6. Add the public key to GitHub as both an **Authentication Key** and a
   **Signing Key**. The key title is also a free-form label, e.g.
   `YubiKey 5C (zbook)`.

7. Run the playbook.

## Reset a YubiKey

Each application on the YubiKey is reset independently with `ykman`. Resets are
irreversible, so reset only the applications needed. A FIDO2 reset is also the
only recovery after 8 incorrect PIN attempts lock FIDO2.

1. If resetting FIDO2, sign in to every website using the YubiKey as a passkey
   or security key another way, and remove or re-register the YubiKey to avoid
   a lockout.

2. If the YubiKey is enrolled for SSH, remove its entry from
   [yubikeys.yml](../yubikeys.yml), its key files from
   `roles/system_administration/files/ssh/`, and its public key from GitHub
   (Authentication and Signing).

3. If PAM U2F (`roles/security/files/yubico/`) is enabled, remove the
   YubiKey's registration from `/etc/u2f_mappings`.

4. Unplug the YubiKey and plug it back in. The YubiKey only accepts a FIDO2
   reset within roughly 10 seconds of being inserted.

5. Reset the required applications, touching the YubiKey when it blinks:

   ```bash
   # FIDO2 / U2F: FIDO2 PIN, passkeys, SSH -sk keys, U2F registrations
   ykman fido reset

   # OpenPGP: GPG keys; PINs return to 123456 / 12345678
   ykman openpgp reset

   # PIV: certificates and keys; PIN, PUK and management key return to defaults
   ykman piv reset

   # OTP: configured OTP slots
   ykman otp delete 1
   ykman otp delete 2

   # OATH: stored TOTP/HOTP accounts
   ykman oath reset
   ```

6. Re-enroll the YubiKey by following [Enroll a YubiKey](#enroll-a-yubikey).
