About
=====
`emrah-jessie` is an installer to create the containerized systems on Debian
Jessie host. It built on top of LXC (Linux containers).

Usage
=====

Download the installer, run it with a template name as an argument and drink a
coffee. That's it.
```
# wget https://raw.githubusercontent.com/emrahcom/emrah-jessie/master/installer/ej
# bash ej <TEMPLATE_NAME>
```

Example
=======

To install a containerized PowerDNS system, login a Debian Jessie host as
`root` and
```
# wget https://raw.githubusercontent.com/emrahcom/emrah-jessie/master/installer/ej
# bash ej ej-powerdns
```

Available templates
===================

ej-powerdns
-----------

Install a ready-to-run DNS system. Main components are:
- PowerDNS server with a PostgreSQL backend
- Poweradmin - the web based control panel for PowerDNS

### To install ej-powerdns

```
# wget https://raw.githubusercontent.com/emrahcom/emrah-jessie/master/installer/ej
# bash ej ej-powerdns
```

### After install ej-powerdns

- `http://<IP_ADDRESS>/poweradmin` to access the DNS control panel
- `https://<IP_ADDRESS>/poweradmin` to access the DNS control panel via HTTPS

### Related links to ej-powerdns

- [PowerDNS] (https://github.com/PowerDNS/pdns)
- [Poweradmin] (https://github.com/poweradmin/poweradmin)
- [PostgreSQL] (https://www.postgresql.org/)

---

ej-email
--------

Install a ready-to-run email system. Main components are:
- Exim4 with a MariaDB backend as SMTP server
- Dovecot as IMAP/POP3 server
- Roundcube as a webmail application
- Vexim2 to manage the virtual mailboxes

### To install ej-email

```
# wget https://raw.githubusercontent.com/emrahcom/emrah-jessie/master/installer/ej
# bash ej ej-email
```

### After install ej-email

- `https://<IP_ADDRESS>/vexim` to manage the virtual mailboxes
- `https://<IP_ADDRESS>/roundcube` as a webmail application
- SMTP: 25 (+STARTTLS) and 587 (+STARTTLS)
- POP3: 110 (+STARTTLS)
- IMAP: 143 (+STARTTLS)

### Related links to ej-email

- [Exim] (http://www.exim.org/)
- [Dovecot] (http://dovecot.org/)
- [Roundcube] (https://roundcube.net/)
- [Vexim2] (https://github.com/vexim/vexim2)

---

ej-livestream
-------------

Install a ready-to-run livestream system. Main components are:
-  Nginx server with nginx-rtmp-module as a stream origin. It gets the RTMP
   stream and convert it to HLS.
-  Nginx server with standart modules as a stream edge. It publish the HLS
   stream.
-  Web based video player

### To install ej-livestream

```
# wget https://raw.githubusercontent.com/emrahcom/emrah-jessie/master/installer/ej
# bash ej ej-livestream
```

### After install ej-livestream

- `rtmp://<IP_ADDRESS>/livestream/<CHANNEL_NAME>` to push a stream (H264/AAC)
- `http://<IP_ADDRESS>/livestream/hls/<CHANNEL_NAME>.m3u8` to pull the HLS stream
- `http://<IP_ADDRESS>/livestream/channel/<CHANNEL_NAME>` for the video player page
- `http://<IP_ADDRESS>:10080/livestream/status` for the RTMP status page

### Related links to ej-livestream

- [nginx-rtmp-module] (https://github.com/arut/nginx-rtmp-module) Arut's repo
- [nginx-rtmp-module] (https://github.com/sergey-dryabzhinsky/nginx-rtmp-module) Sergey's repo
- [video.js] (https://github.com/videojs/video.js)
- [videojs-contrib-hls] (https://github.com/videojs/videojs-contrib-hls)

---

ej-base
-------

Install only a containerized Debian Jessie.

### To install ej-base

```
# wget https://raw.githubusercontent.com/emrahcom/emrah-jessie/master/installer/ej
# bash ej ej-base
```

---

Requirements
============

`emrah-jessie` requires a Debian Jessie host with a minimal install and
Internet access during the installation. It's not a good idea to use your
desktop machine or an already in-use production server as a host machine.
Please, use one of the followings as a host:

-  a cloud host from a hosting/cloud service
   ([Digital Ocean](https://www.digitalocean.com/?refcode=92b0165840d8)'s
   droplet, [Amazon](https://console.aws.amazon.com) EC2 instance etc)
-  a virtual machine (VMware, VirtualBox etc)
-  a Debian Jessie container
-  a physical machine with a fresh installed [Debian Jessie]
   (https://www.debian.org/distrib/netinst)
