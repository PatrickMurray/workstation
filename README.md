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
pacman -S --noconfirm ansible
```


### User

```bash
wget https://www.github.com/patrickmurray/workstation/archive/role_refactor.zip
unzip role_refactor.zip
cd workstation-role_refactor/
ansible-playbook main.yml
```
