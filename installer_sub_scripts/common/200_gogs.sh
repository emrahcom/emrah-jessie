#!/bin/bash

# -----------------------------------------------------------------------------
# GOGS.SH
# -----------------------------------------------------------------------------
set -e
source $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source
[ "$DONT_RUN_GOGS" = true ] && exit

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
MACH="ej-gogs"
ROOTFS="/var/lib/lxc/$MACH/rootfs"
DNS_RECORD=$(grep "address=/$MACH/" /etc/dnsmasq.d/ej_hosts | head -n1)
IP=${DNS_RECORD##*/}
SSH_PORT="30${IP##*.}"
echo GOGS="$IP" >> \
    $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source
cd $BASEDIR/$GIT_LOCAL_DIR/lxc/$MACH

echo
echo "-------------------------- $MACH --------------------------"

# -----------------------------------------------------------------------------
# CONTAINER SETUP
# -----------------------------------------------------------------------------
# remove the old container if exists
set +e
lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED
lxc-destroy -n $MACH
rm -rf /var/lib/lxc/$MACH
set -e

# clone the new one
lxc-clone -o ej-jessie -n $MACH -P /var/lib/lxc/

# shared directories
mkdir -p $SHARED/
cp -arp $BASEDIR/$GIT_LOCAL_DIR/host/usr/local/ej/share $SHARED/

# container config
rm -rf $ROOTFS/var/cache/apt/archives
mkdir -p $ROOTFS/var/cache/apt/archives
sed -i '/\/var\/cache\/apt\/archives/d' /var/lib/lxc/$MACH/config
sed -i '/lxc\.network\./d' /var/lib/lxc/$MACH/config
cat >> /var/lib/lxc/$MACH/config <<EOF

lxc.start.auto = 1
lxc.start.order = 500
lxc.start.delay = 2
lxc.group = ej-group
lxc.group = onboot

lxc.mount.entry = /var/cache/apt/archives \
$ROOTFS/var/cache/apt/archives none bind 0 0

lxc.network.type = veth
lxc.network.flags = up
lxc.network.link = $BRIDGE
lxc.network.name = $PUBLIC_INTERFACE
lxc.network.ipv4 = $IP/24
lxc.network.ipv4.gateway = auto
EOF

# start container
lxc-start -d -n $MACH
lxc-wait -n $MACH -s RUNNING

# -----------------------------------------------------------------------------
# PACKAGES
# -----------------------------------------------------------------------------
# Backports repo (for certbot)
cp etc/apt/sources.list.d/backports.list $ROOTFS/etc/apt/sources.list.d/
cp etc/apt/sources.list.d/mariadb.list $ROOTFS/etc/apt/sources.list.d/

# update
lxc-attach -n $MACH -- apt-key adv --recv-keys --keyserver \
    keyserver.ubuntu.com 0xcbcb082a1bb943db
lxc-attach -n $MACH -- apt-get update
lxc-attach -n $MACH -- apt-get -y dist-upgrade
lxc-attach -n $MACH -- apt-get autoclean

# packages
lxc-attach -n $MACH -- \
    zsh -c \
    "debconf-set-selections <<< \
        'mysql-server mysql-server/root_password password'
     debconf-set-selections <<< \
        'mysql-server mysql-server/root_password_again password'"
lxc-attach -n $MACH -- \
    zsh -c \
    "export DEBIAN_FRONTEND=noninteractive
     apt-get install -y iputils-ping
     apt-get install -y apt-transport-https
     apt-get install -y mariadb-server-10.2
     apt-get install -y nginx-extras ssl-cert ca-certificates
     apt-get install -y -t jessie-backports certbot"
lxc-attach -n $MACH -- \
    zsh -c \
    "export DEBIAN_FRONTEND=noninteractive
     wget -qO - https://deb.packager.io/key | apt-key add -
     echo 'deb https://deb.packager.io/gh/pkgr/gogs jessie pkgr' \
         > /etc/apt/sources.list.d/gogs.list
     apt-get update
     apt-get install -y gogs --install-recommends"

# -----------------------------------------------------------------------------
# GOGS
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- mysql <<EOF
CREATE DATABASE gogs DEFAULT CHARACTER SET utf8;
EOF

lxc-attach -n $MACH -- \
    zsh -c \
    "sed -i 's/^\(SSH_PORT\s*=\).*$/\1 $SSH_PORT/' /etc/gogs/conf/app.ini
     sed -i 's/^\(DOMAIN\s*=\).*$/\1 your.domain.name/' /etc/gogs/conf/app.ini
     sed -i 's/^\(ROOT_URL\s*=\).*$/\1 https:\/\/%(DOMAIN)s\//' \
         /etc/gogs/conf/app.ini
     sed -i 's/^\(FORCE_PRIVATE\s*=\).*$/\1 true/' /etc/gogs/conf/app.ini"

# -----------------------------------------------------------------------------
# SSL
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- \
    zsh -c \
    'cp -ap /etc/ssl/certs/{ssl-cert-snakeoil.pem,ssl-ej.pem}
     cp -ap /etc/ssl/private/{ssl-cert-snakeoil.key,ssl-ej.key}'

# -----------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# -----------------------------------------------------------------------------
cp etc/nginx/conf.d/custom.conf $ROOTFS/etc/nginx/conf.d/
cp etc/nginx/conf.d/proxy_buffer.conf $ROOTFS/etc/nginx/conf.d/
cp etc/nginx/conf.d/proxy.conf $ROOTFS/etc/nginx/conf.d/
cp etc/nginx/sites-available/default $ROOTFS/etc/nginx/sites-available/
cp etc/nginx/snippets/ej_ssl.conf $ROOTFS/etc/nginx/snippets/

# -----------------------------------------------------------------------------
# IPTABLES RULES
# -----------------------------------------------------------------------------
# public ssh
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport $SSH_PORT -j DNAT --to $IP:22 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport $SSH_PORT -j DNAT --to $IP:22

# http
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 80 -j DNAT --to $IP:80 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 80 -j DNAT --to $IP:80

# https
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 443 -j DNAT --to $IP:443 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 443 -j DNAT --to $IP:443

# -----------------------------------------------------------------------------
# CONTAINER SERVICES
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- systemctl restart mysql.service
lxc-attach -n $MACH -- systemctl restart gogs.service
lxc-attach -n $MACH -- systemctl reload nginx.service

lxc-attach -n $MACH -- reboot
lxc-wait -n $MACH -s RUNNING
