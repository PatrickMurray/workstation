# Workstation Deployment Automation


## Prerequisites


```bash
$ su
root $ nano /etc/apt/sources.list # remove cdrom
root $ apt-get update
root $ apt-get -y upgrade
root $ apt-get -y install unzip ansible sudo
root $ echo "patrick ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/patrick
root $ exit
$ wget https://www.github.com/patrickmurray/workstation/archive/master.zip
$ unzip master.zip
$ cd workstation-master/
$ ansible-playbook workstation.yml # upgrade distribution
$ ansible-playbook workstation.yml # complete configuration
```

