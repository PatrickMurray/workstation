# Workstation Configuration


## Operating System Support

| Operating Systemn | Release | Date Tested |
| ----------------- | ------- | ----------- |
| Ubuntu Desktop    | 22.04   | 2023-04-22  |


## Screenshots

![screenshot](docs/images/screenshot.png)


## Installation


### Root

```bash
# Install Ansible
apt-get install -r python3-pip
pip3 install ansible

# Fetch Configuration Management
wget https://www.github.com/patrickmurray/workstation/archive/master.zip
unzip master.zip
cd workstation-master/

# Configure :)
#ansible-galaxy install -r requirements.yml
ansible-playbook main.yml
```

