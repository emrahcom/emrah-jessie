About
=====

`emrah-jessie` is an installer to create the containerized systems on Debian
Jessie host. It built on top of LXC (Linux containers).

Table of contents
=================

- [About](#about)
- [Usage](#usage)
- [Example](#example)
- [Available templates](#available-templates)
    - [ej-base](#ej-base)
        - [To install ej-base](#to-install-ej-base)
    - [ej-email](#ej-email)
        - [Main components of ej-email](#main-components-of-ej-email)
        - [To install ej-email](#to-install-ej-email)
        - [After install ej-email](#after-install-ej-email)
        - [SSL certificate for ej-email](#ssl-certificate-for-ej-email)
        - [Related links to ej-email](#related-links-to-ej-email)
    - [ej-gogs](#ej-gogs)
        - [Main components of ej-gogs](#main-components-of-ej-gogs)
        - [To install ej-gogs](#to-install-ej-gogs)
        - [After install ej-gogs](#after-install-ej-gogs)
        - [SSL certificate for ej-gogs](#ssl-certificate-for-ej-gogs)
        - [Related links to ej-gogs](#related-links-to-ej-gogs)
    - [ej-livestream](#ej-livestream)
        - [Main components of ej-livestream](#main-components-of-ej-livestream)
        - [To install ej-livestream](#to-install-ej-livestream)
        - [After install ej-livestream](#after-install-ej-livestream)
        - [Related links to ej-livestream](#related-links-to-ej-livestream)
    - [ej-powerdns](#ej-powerdns)
        - [Main components of ej-powerdns](#main-components-of-ej-powerdns)
        - [To install ej-powerdns](#to-install-ej-powerdns)
        - [After install ej-powerdns](#after-install-ej-powerdns)
        - [Related links to ej-powerdns](#related-links-to-ej-powerdns)
    - [ej-waf](#ej-waf)
        - [Main components of ej-waf](#main-components-of-ej-waf)
        - [To install ej-waf](#to-install-ej-waf)
        - [After install ej-waf](#after-install-ej-waf)
        - [Related links to ej-waf](#related-links-to-ej-waf)
- [Requirements](#requirements)

---

Usage
=====

Download the installer, run it with a template name as an argument and drink a
coffee. That's it.

```bash
wget https://raw.githubusercontent.com/emrahcom/emrah-jessie/master/installer/ej
bash ej <TEMPLATE_NAME>
```

Example
=======

To install a containerized PowerDNS system, login a Debian Jessie host as
`root` and

```bash
wget https://raw.githubusercontent.com/emrahcom/emrah-jessie/master/installer/ej
bash ej ej-powerdns
```

Available templates
===================

ej-base
-------

Install only a containerized Debian Jessie.

### To install ej-base

```bash
wget https://raw.githubusercontent.com/emrahcom/emrah-jessie/master/installer/ej
bash ej ej-base
```

---

ej-email
--------

Install a ready-to-use email system.

### Main components of ej-email

- Exim4 with a MariaDB backend as SMTP server
- Dovecot as IMAP/POP3 server
- Roundcube as a webmail application
- Vexim2 to manage the virtual mailboxes
- SpamAssassin as a spam filter
- ClamAV as a virus scanner

### To install ej-email

```bash
wget https://raw.githubusercontent.com/emrahcom/emrah-jessie/master/installer/ej
bash ej ej-email
```

### After install ej-email

- `https://<IP_ADDRESS>/vexim` to manage the virtual mailboxes
- `https://<IP_ADDRESS>/roundcube` as a webmail application
- SMTP: 25 (+STARTTLS) and 587 (+STARTTLS)
- POP3: 110 (+STARTTLS)
- POP3S: 995 (SSL/TLS)
- IMAP: 143 (+STARTTLS)
- IMAPS: 993 (SSL/TLS)

### SSL certificate for ej-email

To use Let's Encrypt certificate, connect to ej-email container as root and

```bash
FQDN="your.host.fqdn"

certbot certonly --webroot -w /var/www/html -d $FQDN

chmod 750 /etc/letsencrypt/{archive,live}
chown root:ssl-cert /etc/letsencrypt/{archive,live}
mv /etc/ssl/certs/{ssl-ej.pem,ssl-ej.pem.bck}
mv /etc/ssl/private/{ssl-ej.key,ssl-ej.key.bck}
ln -s /etc/letsencrypt/live/$FQDN/fullchain.pem \
    /etc/ssl/certs/ssl-ej.pem
ln -s /etc/letsencrypt/live/$FQDN/privkey.pem \
    /etc/ssl/private/ssl-ej.key

systemctl restart exim4.service
systemctl restart dovecot.service
systemctl restart apache2.service
```


### Related links to ej-email

- [Exim](http://www.exim.org/)
- [Dovecot](http://dovecot.org/)
- [Roundcube](https://roundcube.net/)
- [Vexim2](https://github.com/vexim/vexim2)
- [SpamAssassin](https://spamassassin.apache.org/)
- [ClamAV](https://www.clamav.net/)
- [MariaDB](https://mariadb.org/)
- [Let's Encrypt](https://letsencrypt.org/)
- [Certbot](https://certbot.eff.org/)

---

ej-gogs
--------

Install a ready-to-use self-hosted Git service. Only AMD64 architecture is
supported for this template.

### Main components of ej-gogs

- Gogs
- Git
- Nginx
- MariaDB

### To install ej-gogs

```bash
wget https://raw.githubusercontent.com/emrahcom/emrah-jessie/master/installer/ej
bash ej ej-gogs
```

### After install ej-gogs

-  Access `https://<IP_ADDRESS>/` to finish the installation process. Easy!

-  **Password**: There is no password for the database. So, leave it blank!
   Don't worry, only the local user can connect to the database server.

-  **Domain**: Write your host FQDN or IP address. Examples:
   *git.mydomain.com*  *123.2.3.4*

-  **SSH Port**: Leave the default value which is the SSH port of the
   container.

-  **HTTP Port**: Leave the default value which is the internal port of Gogs
   service.

-  **Application URL**: Write your URL. HTTP and HTTPS are OK. Examples:
   *https://git.mydomain.com/*  *https://123.2.3.4/*

-  The first registered user will be the administrator.


### SSL certificate for ej-gogs

To use Let's Encrypt certificate, connect to ej-gogs container as root and

```bash
FQDN="your.host.fqdn"

certbot certonly --webroot -w /var/www/html -d $FQDN

chmod 750 /etc/letsencrypt/{archive,live}
chown root:ssl-cert /etc/letsencrypt/{archive,live}
mv /etc/ssl/certs/{ssl-ej.pem,ssl-ej.pem.bck}
mv /etc/ssl/private/{ssl-ej.key,ssl-ej.key.bck}
ln -s /etc/letsencrypt/live/$FQDN/fullchain.pem \
    /etc/ssl/certs/ssl-ej.pem
ln -s /etc/letsencrypt/live/$FQDN/privkey.pem \
    /etc/ssl/private/ssl-ej.key

systemctl restart nginx.service
```


### Related links to ej-gogs

- [Gogs](https://gogs.io/)
- [Git](https://git-scm.com/)
- [Nginx](http://nginx.org/)
- [MariaDB](https://mariadb.org/)
- [Let's Encrypt](https://letsencrypt.org/)
- [Certbot](https://certbot.eff.org/)

---

ej-livestream
-------------

Install a ready-to-use livestream system.

### Main components of ej-livestream

-  Nginx server with nginx-rtmp-module as a stream origin. It gets the RTMP
   stream and convert it to HLS.

-  Nginx server with standart modules as a stream edge. It publish the HLS
   stream.

-  Web based video player

### To install ej-livestream

```bash
wget https://raw.githubusercontent.com/emrahcom/emrah-jessie/master/installer/ej
bash ej ej-livestream
```

### After install ej-livestream

-  `rtmp://<IP_ADDRESS>/livestream/<CHANNEL_NAME>` to push a stream (H264/AAC)

-  `http://<IP_ADDRESS>/livestream/hls/<CHANNEL_NAME>.m3u8` to pull the HLS
   stream

-  `http://<IP_ADDRESS>/livestream/channel/<CHANNEL_NAME>` for the video player
   page

-  `http://<IP_ADDRESS>:10080/livestream/status` for the RTMP status page

### Related links to ej-livestream

-  [nginx-rtmp-module](https://github.com/arut/nginx-rtmp-module) Arut's repo

-  [nginx-rtmp-module](https://github.com/sergey-dryabzhinsky/nginx-rtmp-module)
   Sergey's repo

-  [video.js](https://github.com/videojs/video.js)

-  [videojs-contrib-hls](https://github.com/videojs/videojs-contrib-hls)

---

ej-powerdns
-----------

Install a ready-to-use DNS system.

### Main components of ej-powerdns

- PowerDNS server with a PostgreSQL backend
- Poweradmin - the web based control panel for PowerDNS

### To install ej-powerdns

```bash
wget https://raw.githubusercontent.com/emrahcom/emrah-jessie/master/installer/ej
bash ej ej-powerdns
```

### After install ej-powerdns

- `http://<IP_ADDRESS>/poweradmin` to access the DNS control panel
- `https://<IP_ADDRESS>/poweradmin` to access the DNS control panel via HTTPS

### Related links to ej-powerdns

- [PowerDNS](https://github.com/PowerDNS/pdns)
- [Poweradmin](https://github.com/poweradmin/poweradmin)
- [PostgreSQL](https://www.postgresql.org/)

---

ej-waf
-----------

Install a ready-to-use WAF (Web Application Firewall) system.

### Main components of ej-waf

- lua-resty-waf - High-performance WAF built on the OpenResty stack
- Nginx as the proxy server

### To install ej-waf

```bash
wget https://raw.githubusercontent.com/emrahcom/emrah-jessie/master/installer/ej
bash ej ej-waf
```

### After install ej-waf

-  Edit `/etc/nginx/conf.d/upstream.conf` file in `ej-waf` container to set
   your backend server

### Related links to ej-waf

- [lua-resty-waf](https://github.com/p0pr0ck5/lua-resty-waf)
- [Nginx](http://nginx.org/)

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

-  a physical machine with a fresh installed
   [Debian Jessie](https://www.debian.org/distrib/netinst)
