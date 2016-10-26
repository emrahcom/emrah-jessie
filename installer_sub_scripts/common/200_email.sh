#!/bin/bash

# -----------------------------------------------------------------------------
# EMAIL.SH
# -----------------------------------------------------------------------------
set -e
source $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source
[ "$DONT_RUN_EMAIL" = true ] && exit

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
MACH="ej-email"
ROOTFS="/var/lib/lxc/$MACH/rootfs"
DNS_RECORD=$(grep "address=/$MACH/" /etc/dnsmasq.d/ej_hosts | head -n1)
IP=${DNS_RECORD##*/}
SSH_PORT="30${IP##*.}"
echo EMAIL="$IP" >> \
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
# update
lxc-attach -n $MACH -- apt-get update
lxc-attach -n $MACH -- apt-get -y dist-upgrade
lxc-attach -n $MACH -- apt-get autoclean

# packages
lxc-attach -n $MACH -- \
    debconf-set-selections <<< \
    'mysql-server mysql-server/root_password password'
lxc-attach -n $MACH -- \
    debconf-set-selections <<< \
    'mysql-server mysql-server/root_password_again password'
lxc-attach -n $MACH -- \
    zsh -c \
    'export DEBIAN_FRONTEND=noninteractive
     apt-get install -y iputils-ping
     apt-get install -y mariadb-server
     apt-get install -y apache2 libapache2-mod-php5 \
         php5-mysql php5-imap ssl-cert
     apt-get install -y exim4-daemon-heavy
     apt-get install -y clamav-daemon clamav-freshclam \
         spamassassin --install-recommends'

# -----------------------------------------------------------------------------
# EXIM4
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- \
    zsh -c \
    "sed -i \
     \"s/^dc_eximconfig_configtype.*$/dc_eximconfig_configtype='internet'/\" \
     /root/update-exim4.conf.conf

     sed -i \
     \"s/^dc_local_interfaces.*$/dc_local_interfaces=''/\" \
     /root/update-exim4.conf.conf

     sed -i \
     \"s/^dc_use_split_config*$/dc_use_split_config='true'/\" \
     /root/update-exim4.conf.conf

     sed -i \
     \"s/^dc_localdelivery*$/dc_localdelivery='maildir_home'/\" \
     /root/update-exim4.conf.conf

     update-exim4.conf"

# -----------------------------------------------------------------------------
# VEXIM2
# -----------------------------------------------------------------------------
# clone vexim2 repo
mkdir $ROOTFS/tmp/vexim2
git clone --depth=1 https://github.com/vexim/vexim2.git $ROOTFS/tmp/vexim2

# system user for virtual mailboxes
lxc-attach -n $MACH -- \
    zsh -c \
    'adduser --system --home /var/vmail --disabled-password --disabled-login \
             --group vexim'
UID=$(lxc-attach -n $MACH -- grep vexim /etc/passwd | cut -d':' -f3)
GID=$(lxc-attach -n $MACH -- grep vexim /etc/passwd | cut -d':' -f4)

# vexim database
VEXIM_PASSWD=`(echo -n $RANDOM$RANDOM; cat /proc/sys/kernel/random/uuid) | \
    sha256sum | cut -c 1-20`

lxc-attach -n $MACH -- mysql <<EOF
CREATE DATABASE vexim DEFAULT CHARACTER SET utf8;
CREATE USER 'vexim'@'127.0.0.1';
SET PASSWORD FOR 'vexim'@'127.0.0.1' = PASSWORD('$VEXIM_PASSWD');
GRANT SELECT,INSERT,DELETE,UPDATE ON vexim.* to 'vexim'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF

lxc-attach -n $MACH -- \
    zsh -c \
    'mysql vexim </tmp/vexim2/setup/mysql.sql >/tmp/secret'

# vexim siteadmin account
VEXIM_WEB_USER=$(egrep -i '^\s*user' $ROOTFS/tmp/secret | \
                 cut -d ':' -f2 | xargs)
VEXIM_WEB_PASSWD=$(egrep -i '^\s*password' $ROOTFS/tmp/secret | \
                   cut -d ':' -f2 | xargs)
rm $ROOTFS/tmp/secret
echo VEXIM_WEB_USER="$VEXIM_WEB_USER" >> \
    $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source
echo VEXIM_WEB_PASSWD="$VEXIM_WEB_PASSWD" >> \
    $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source

# vexim site
lxc-attach -n $MACH -- \
    zsh -c \
    'cp -r /tmp/vexim2/vexim /var/www/html
     mv /var/www/html/vexim/config/{variables.php.example,variables.php}'
lxc-attach -n $MACH -- \
    zsh -c \
    "sed -i 's/\$sqlpass.*$/\$sqlpass = \"$VEXIM_PASSWD\";/' \
         /var/www/html/vexim/config/variables.php
     sed -i 's/\$uid.*$/\$uid = \"$UID\";/' \
         /var/www/html/vexim/config/variables.php
     sed -i 's/\$gid.*$/\$gid = \"$GID\";/' \
         /var/www/html/vexim/config/variables.php"

# -----------------------------------------------------------------------------
# IPTABLES RULES
# -----------------------------------------------------------------------------
# public ssh
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport $SSH_PORT -j DNAT --to $IP:22 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport $SSH_PORT -j DNAT --to $IP:22

# web panel
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 80 -j DNAT --to $IP:80 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 80 -j DNAT --to $IP:80
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 443 -j DNAT --to $IP:443 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 443 -j DNAT --to $IP:443

# -----------------------------------------------------------------------------
# CONTAINER SERVICES
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- reboot
lxc-wait -n $MACH -s RUNNING
