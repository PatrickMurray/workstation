# Workstation Configuration


## Operating System Support

| Distribution | Date Tested |
| ------------ | ----------- |
| Arch Linux   | 2019-02-24  |


## Screenshots

![screenshot](docs/images/screenshot.png)


## Installation


### Root

```bash
# Install Ansible
pacman -S --noconfirm ansible

# Fetch Configuration Management
wget https://www.github.com/patrickmurray/workstation/archive/master.zip
unzip role_refactor.zip
cd workstation-role_master/

# Configure :)
ansible-playbook main.yml
```
