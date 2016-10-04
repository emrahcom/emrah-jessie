## About
`emrah-jessie` is an installer to create the containerized systems on Debian Jessie box.
It built on top of LXC (Linux containers).

## Usage
Download the installer and run it with a template name as argument.
```
	# wget https://raw.githubusercontent.com/emrahcom/emrah-jessie/master/installer/ej
	# bash ej <TEMPLATE_NAME>
```

## Example
To install a containerized PowerDNS system, login a Debian Jessie box as `root` and
```
	# wget https://raw.githubusercontent.com/emrahcom/emrah-jessie/master/installer/ej
	# bash ej ej-powerdns
```

## Available templates
### ej-base
Install only a containerized Debian Jessie.

### ej-powerdns
Install a ready-to-run DNS system. Main components are:
* PowerDNS server with a PostgreSQL backend
* Poweradmin - the web based control panel for PowerDNS

### ej-livestream
Install a ready-to-run livestream system. Main components are:
* Nginx server with nginx-rtmp-module as a stream origin. It gets the RTMP stream and convert it to HLS
* Nginx server with standart modules as a stream edge. It publish the HLS stream.

## Requirements
`emrah-jessie` requires a Debian Jessie host with a minimal install and Internet access during the installation. It's not a good idea to use a desktop machine or a production server as a host machine. Please, use one of the following as a host:
* a cloud host from a hosting/cloud service (Digital Ocean's droplet, Amazon EC2 instance etc)
* a virtual machine (VMware, VirtualBox etc)
* a Linux container (LXC)
* a physical machine with a fresh installed Debian Jessie
