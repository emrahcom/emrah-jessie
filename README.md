## About
`emrah-jessie` is an installer to create the containerized systems on Debian Jessie box.
It built on top of the Linux containers (LXC).

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

## Available template
### ej-base
Install only a containerezed Debian Jessie.

### ej-powerdns
Install a ready-to-run DNS system. Main component are:
* PowerDNS server with a PostgreSQL backend
* Poweradmin - the web based control panel for PowerDNS

### ej-livestream
Install a ready-to-run livestream system. Main component are:
* Nginx server with nginx-rtmp-module as a stream origin. It gets the RTMP stream and convert it to HLS
* Nginx server with standart modules as a stream edge. It publish the HLS stream.
