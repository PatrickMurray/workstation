# Keyring

SSH authentication, git commit signing and GPG use the passphrase-protected
workstation keys. Their passphrases are stored in the GNOME login keyring, which
is unlocked by the login password, so the keys are usable without prompting
once logged in.

## How It Works

- **SSH:** `gcr-ssh-agent` is the SSH agent (`SSH_AUTH_SOCK` is
  `/run/user/<uid>/gcr/ssh`). It lists every key pair in `~/.ssh` and unlocks a
  key on first use with the passphrase stored in the keyring.
- **Commit signing:** git signs with the workstation SSH key
  (`user.signingkey` is its `.pub` file), so `ssh-keygen` signs via the agent.
- **GPG:** `gpg-agent` uses `pinentry-gnome3`, which reads and stores
  passphrases in the keyring.

## Store the Passphrases

After running the playbook on a new workstation, log out and back in, then
store each passphrase once:

1. **SSH:** connect to a host that accepts the workstation key:

   ```bash
   ssh -T git@github.com
   ```

   Enter the passphrase in the GNOME prompt and tick **Automatically unlock
   this key whenever I'm logged in**.

2. **GPG:** sign something with the GPG key:

   ```bash
   echo test | gpg --clearsign > /dev/null
   ```

   Enter the passphrase in the GNOME prompt and tick **Save in password
   manager**.

Stored passphrases are listed in **Passwords and Keys** (Seahorse) under the
**Login** keyring, where they can be removed to prompt again.

## Security

- The keyring is encrypted with the login password, so the keys are as safe at
  rest as the login password (with full-disk encryption).
- While logged in, any process running as the user can use the agents or read
  the keyring without a prompt.
- The keyring is only unlocked by a password login. Logging in another way
  (e.g. fingerprint) leaves it locked, and the passphrases
  are prompted for again.
