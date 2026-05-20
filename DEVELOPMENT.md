# Development

## Pre-Commit Hooks

This repository uses pre-commit hooks to ensure code quality and prevent committing secrets.

### Setup

After cloning the repository:

1. Run the Ansible playbook to install dependencies, see the Installation section of [README.md](README.md) for details.

2. Install the git hooks:

   ```bash
   pre-commit install
   ```

3. Verify installation:

   ```bash
   pre-commit run --all-files
   ```

### What It Checks

- ansible-vault encryption for role defaults files and secrets.yml
- YAML syntax validation
- Large file detection
- Trailing whitespace and end-of-file formatting
- Merge conflict markers

### Bypassing Hooks

If you need to bypass the pre-commit hooks for a specific commit:

```bash
git commit --no-verify -m "Your commit message"
```

## Time-Sensitive Configurations

### Tailscale Network Configuration

This playbook automatically configures workstations to join the Tailscale mesh network using an auth key stored in `roles/network/defaults/main.yml`.

#### Key Management

**Important**: Tailscale auth keys have a maximum expiration of 90 days due to Tailscale API limitations. You must periodically re-issue the auth key to maintain network connectivity.

##### Generate Auth Key:

1. Navigate to the infracode repository: [github.com/patrickmurray/infracode](https://github.com/patrickmurray/infracode)

2. Apply the Terraform configuration to generate a new auth key:

   ```bash
   terraform apply
   ```

3. Get the new auth key:

   ```bash
   terraform output mesh_network_auth_keys
   ```

4. Update the workstation repository with the new key

   ```bash
   ansible-vault decrypt roles/network/defaults/main.yml
   # Edit
   ansible-vault encrypt roles/network/defaults/main.yml
   ```

5. Commit and push the updated key:

   ```bash
   git add roles/network/defaults/main.yml
   git commit -m "Update Tailscale auth key"
   git push
   ```
