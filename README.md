# Workstation Configuration


## Operating System Support

| Operating Systemn | Release | Date Tested |
| ----------------- | ------- | ----------- |
| Debian            | 10.0    | 2019-07-07  |


## Screenshots

![screenshot](docs/images/screenshot.png)


## Installation


### Root

```bash
# Install Dependencies
apt install  \
  -y  \
  unzip  \
  gnupg  \
  wget  \
  python3-pip  \
  git  \
  libc-bin;

# Install Ansible
pip3 install ansible

# Fetch Configuration Management
wget https://www.github.com/patrickmurray/workstation/archive/master.zip
unzip master.zip
cd workstation-master/

# Configure :)
ansible-playbook main.yml
```


## To-Do

1) Wireless firmware
2) WPA supplicant configuration & testing
3) Move user password to Ansible vault
4) Setup Resilio-Sync
