#!/bin/bash

# -----------------------------------------------------------------------------
# POWERDNS.SH
# -----------------------------------------------------------------------------
set -e
source $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source
[ "$DONT_RUN_POWERDNS" = true ] && exit

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
MACH="ej-powerdns"
ROOTFS="/var/lib/lxc/$MACH/rootfs"
DNS_RECORD=$(grep "address=/$MACH/" /etc/dnsmasq.d/ej_hosts | head -n1)
IP=${DNS_RECORD##*/}
SSH_PORT="30${IP##*.}"
echo POWERDNS="$IP" >> \
    $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source
cd $BASEDIR/$GIT_LOCAL_DIR/lxc/$MACH

echo
echo "-------------------- $MACH --------------------"

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
/var/lib/lxc/$MACH/rootfs/var/cache/apt/archives none bind 0 0

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
# update
lxc-attach -n $MACH -- apt-get update
lxc-attach -n $MACH -- apt-get -y dist-upgrade
lxc-attach -n $MACH -- apt-get autoclean

# packages
lxc-attach -n $MACH -- \
    debconf-set-selections <<< \
    'pdns-backend-pgsql pdns-backend-pgsql/dbconfig-install boolean true'
lxc-attach -n $MACH -- \
    debconf-set-selections <<< \
    'pdns-backend-pgsql pdns-backend-pgsql/pgsql/app-pass password '
lxc-attach -n $MACH -- \
    zsh -c \
    'export DEBIAN_FRONTEND=noninteractive
     apt-get install -y iputils-ping
     apt-get install -y postgresql postgresql-contrib --install-recommends
     apt-get install -y pdns-server pdns-backend-pgsql
     apt-get install -y apache2 libapache2-mod-php5 \
         php5 php5-mcrypt php-pear php-mdb2 php-mdb2-driver-pgsql php5-pgsql \
	 ssl-cert'

# -----------------------------------------------------------------------------
# POWERADMIN
# -----------------------------------------------------------------------------
mkdir $ROOTFS/var/www/html/poweradmin
git clone --depth=1 https://github.com/poweradmin/poweradmin.git \
    $ROOTFS/var/www/html/poweradmin
rm -rf $ROOTFS/var/www/html/poweradmin/.git
rm -f $ROOTFS/var/www/html/poweradmin/.gitignore
rm -rf $ROOTFS/var/www/html/poweradmin/install

# poweradmin database config
cp tmp/poweradmin_permission.sql $ROOTFS/tmp/
POWERADMIN_DB_PASSWD=`(echo -n $RANDOM$RANDOM; \
	               cat /proc/sys/kernel/random/uuid) | \
		       sha256sum | cut -d" " -f1`
POWERADMIN_WEB_PASSWORD=`echo $POWERADMIN_DB_PASSWD | cut -c1-20`

lxc-attach -n $MACH -- \
    su -l postgres -c \
    "psql <<< \"CREATE USER poweradmin PASSWORD '$POWERADMIN_DB_PASSWD';\""
lxc-attach -n $MACH -- \
    su -l postgres -c \
    "psql pdns < /var/www/html/poweradmin/sql/poweradmin-pgsql-db-structure.sql"
lxc-attach -n $MACH -- \
    su -l postgres -c \
    "psql pdns < /tmp/poweradmin_permission.sql"
lxc-attach -n $MACH -- \
    su -l postgres -c \
    "psql pdns << EOF
         UPDATE users
         SET password = md5('$POWERADMIN_WEB_PASSWORD')
	 WHERE username = 'admin';
EOF"

# -----------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# -----------------------------------------------------------------------------
cp var/www/html/index.html $ROOTFS/var/www/html/
cp etc/apache2/conf-available/servername.conf \
    $ROOTFS/etc/apache2/conf-available/
cp var/www/html/poweradmin/inc/config.inc.php \
    $ROOTFS/var/www/html/poweradmin/inc/

sed -i "s/#POWERADMIN_PASSWORD#/$POWERADMIN_DB_PASSWD/g" \
    $ROOTFS/var/www/html/poweradmin/inc/config.inc.php

SESS_KEY=`(echo -n $RANDOM$RANDOM; cat /proc/sys/kernel/random/uuid) | \
          sha256sum | cut -c1-46`
sed -i "s/#SESSION_KEY#/$SESS_KEY/g" \
    $ROOTFS/var/www/html/poweradmin/inc/config.inc.php

# -----------------------------------------------------------------------------
# IPTABLES RULES
# -----------------------------------------------------------------------------
# public ssh
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport $SSH_PORT -j DNAT --to $IP:22 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport $SSH_PORT -j DNAT --to $IP:22

# dns query
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p udp --dport 53 -j DNAT --to $IP:53 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p udp --dport 53 -j DNAT --to $IP:53
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 53 -j DNAT --to $IP:53 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 53 -j DNAT --to $IP:53

# web panel (poweradmin)
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 80 -j DNAT --to $IP:80 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 80 -j DNAT --to $IP:80
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 443 -j DNAT --to $IP:443 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 443 -j DNAT --to $IP:443

# -----------------------------------------------------------------------------
# CONTAINER SERVICES
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- a2ensite default-ssl.conf
lxc-attach -n $MACH -- a2enconf servername
lxc-attach -n $MACH -- a2enmod ssl
lxc-attach -n $MACH -- systemctl reload apache2
lxc-attach -n $MACH -- reboot
