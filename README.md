About
=====
`emrah-jessie` is an installer to create the containerized systems on Debian Jessie host.
It built on top of LXC (Linux containers).

Usage
=====
Download the installer, run it with a template name as an argument and drink a coffee. That's it.
```
	# wget https://raw.githubusercontent.com/emrahcom/emrah-jessie/master/installer/ej
	# bash ej <TEMPLATE_NAME>
```

Example
=======
To install a containerized PowerDNS system, login a Debian Jessie host as `root` and
```
	# wget https://raw.githubusercontent.com/emrahcom/emrah-jessie/master/installer/ej
	# bash ej ej-powerdns
```

Available templates
===================
### ej-base
Install only a containerized Debian Jessie.

### ej-powerdns
Install a ready-to-run DNS system. Main components are:
* PowerDNS server with a PostgreSQL backend
* Poweradmin - the web based control panel for PowerDNS

After install:
* `http://<IP_ADDRESS>/poweradmin` to access the DNS control panel
* `https://<IP_ADDRESS>/poweradmin` to access the DNS control panel via HTTPS

Related links:
* [PowerDNS] (https://github.com/PowerDNS/pdns)
* [Poweradmin] (https://github.com/poweradmin/poweradmin)

### ej-livestream
Install a ready-to-run livestream system. Main components are:
* Nginx server with nginx-rtmp-module as a stream origin. It gets the RTMP stream and convert it to HLS.
* Nginx server with standart modules as a stream edge. It publish the HLS stream.
* Web based video player

After install:
* `rtmp://<IP_ADDRESS>/livestream/<CHANNEL_NAME>` to push a stream (H264/AAC)
* `http://<IP_ADDRESS>/livestream/hls/<CHANNEL_NAME>.m3u8` to pull the HLS stream
* `http://<IP_ADDRESS>/livestream/channel/<CHANNEL_NAME>` for the video player page
* `http://<IP_ADDRESS>:10080/livestream/status` for the RTMP status page

Related links:
* [nginx-rtmp-module] (https://github.com/arut/nginx-rtmp-module) Arut's repo
* [nginx-rtmp-module] (https://github.com/sergey-dryabzhinsky/nginx-rtmp-module) Sergey's repo
* [video.js] (https://github.com/videojs/video.js)
* [videojs-contrib-hls] (https://github.com/videojs/videojs-contrib-hls)

Requirements
============
`emrah-jessie` requires a Debian Jessie host with a minimal install and Internet access during the installation. It's not a good idea to use your desktop machine or an already in-use production server as a host machine. Please, use one of the followings as a host:
* a cloud host from a hosting/cloud service ([Digital Ocean](https://www.digitalocean.com/?refcode=92b0165840d8)'s droplet, [Amazon](https://console.aws.amazon.com) EC2 instance etc)
* a virtual machine (VMware, VirtualBox etc)
* a Debian Jessie container
* a physical machine with a fresh installed [Debian Jessie] (https://www.debian.org/distrib/netinst)
