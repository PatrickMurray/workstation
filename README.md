# Workstation

## Operating System Support

| Operating System | Release | Date Tested |
| ---------------- | ------- | ----------- |
| Fedora           | 44      | 2026-06-04 |

## Screenshots

![screenshot](docs/images/screenshot.png)

## Installation

### Interactive

Run the below command from a `root` shell:

```bash
bash -c "$(curl -fsSl https://raw.githubusercontent.com/PatrickMurray/workstation/HEAD/install.sh)"
```

### Manual

Run one of the below commands from a `root` shell:

```bash
# Default workstation
ansible-playbook \
  --inventory inventory.yml \
  main.yml;

# Slim workstation
ansible-playbook \
  --inventory inventory.yml \
  --extra-vars "workstation_type=slim" \
  main.yml;
```

For development setup, see [DEVELOPMENT.md](DEVELOPMENT.md).
