# Workstation Configuration


## Operating System Support

| Operating Systemn | Release | Date Tested |
| ----------------- | ------- | ----------- |
| Fedora            | 37      | 2022-11-19  |


## Screenshots

![screenshot](docs/images/screenshot.png)


## Installation


### Root

```bash
# Install Ansible
dnf install -y ansible-core

# Fetch Configuration Management
wget https://www.github.com/patrickmurray/workstation/archive/master.zip
unzip master.zip
cd workstation-master/

# Configure :)
ansible-galaxy install -r requirements.yml
ansible-playbook main.yml
```

