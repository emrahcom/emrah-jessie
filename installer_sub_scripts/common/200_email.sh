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

# FQDN sample
lxc-attach -n $MACH -- \
    zsh -c \
    "echo '127.0.1.1\t$MACH.mydomain.com $MACH' >>/etc/hosts"

# -----------------------------------------------------------------------------
# PACKAGES
# -----------------------------------------------------------------------------
# Backports repo (for roundcube)
cp etc/apt/sources.list.d/backports.list $ROOTFS/etc/apt/sources.list.d/

# update
lxc-attach -n $MACH -- apt-get update
lxc-attach -n $MACH -- apt-get -y dist-upgrade
lxc-attach -n $MACH -- apt-get autoclean

# packages
lxc-attach -n $MACH -- \
    zsh -c \
    "debconf-set-selections <<< \
        'mysql-server mysql-server/root_password password'
     debconf-set-selections <<< \
        'mysql-server mysql-server/root_password_again password'
     debconf-set-selections <<< \
        'roundcube-core roundcube/dbconfig-install boolean true'
     debconf-set-selections <<< \
        'roundcube-core roundcube/database-type select mysql'
     debconf-set-selections <<< \
        'roundcube-core roundcube/mysql/admin-pass password'
     debconf-set-selections <<< \
        'roundcube-core roundcube/mysql/app-pass password'
	     "
lxc-attach -n $MACH -- \
    zsh -c \
    'export DEBIAN_FRONTEND=noninteractive
     apt-get install -y iputils-ping
     apt-get install -y mariadb-server
     apt-get install -y apache2 libapache2-mod-php5 \
         php5-mysql php5-imap ssl-cert
     apt-get install -y exim4-daemon-heavy bsd-mailx
     apt-get install -y clamav-daemon clamav-freshclam libclamunrar7 \
         spamassassin --install-recommends
     apt-get install -y dovecot-core dovecot-imapd dovecot-pop3d \
         dovecot-mysql dovecot-managesieved
     apt-get install -y roundcube-core roundcube-mysql \
         roundcube-plugins --install-recommends'

# -----------------------------------------------------------------------------
# SSL
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- \
    zsh -c \
    'cp -ap /etc/ssl/certs/{ssl-cert-snakeoil.pem,ssl-ej-email.pem}
     cp -ap /etc/ssl/private/{ssl-cert-snakeoil.key,ssl-ej-email.key}'

# -----------------------------------------------------------------------------
# SPAMASSASSIN
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- \
    zsh -c \
    "sed -i 's/^CRON=.*$/CRON=1/' /etc/default/spamassassin

     sa-update -v
     systemctl enable spamassassin.service
     systemctl start spamassassin.service"

# -----------------------------------------------------------------------------
# FRESHCLAM
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- \
    zsh -c \
    "systemctl stop clamav-freshclam.service
     freshclam
     systemctl start clamav-freshclam.service"


# -----------------------------------------------------------------------------
# CLAMAV
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- \
    zsh -c \
    "adduser clamav Debian-exim
     systemctl enable clamav-daemon.service
     systemctl restart clamav-daemon.service"

# -----------------------------------------------------------------------------
# EXIM4
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- \
    zsh -c \
    "sed -i \
     \"s/^dc_eximconfig_configtype.*$/dc_eximconfig_configtype='internet'/\" \
     /etc/exim4/update-exim4.conf.conf

     sed -i \
     \"s/^dc_local_interfaces.*$/dc_local_interfaces=''/\" \
     /etc/exim4/update-exim4.conf.conf

     sed -i \
     \"s/^dc_use_split_config.*$/dc_use_split_config='true'/\" \
     /etc/exim4/update-exim4.conf.conf

     sed -i \
     \"s/^dc_localdelivery.*$/dc_localdelivery='maildir_home'/\" \
     /etc/exim4/update-exim4.conf.conf

     sed -i 's/^\(SMTPLISTENEROPTIONS.*\)$/#\1/' /etc/default/exim4

     echo \"SMTPLISTENEROPTIONS='-oX 25:587 -oP /var/run/exim4/exim.pid'\" >> \
     /etc/default/exim4

     update-exim4.conf
     adduser Debian-exim ssl-cert
     systemctl restart exim4.service"

# -----------------------------------------------------------------------------
# VEXIM2
# -----------------------------------------------------------------------------
# clone vexim2 repo
git clone --depth=1 https://github.com/vexim/vexim2.git $ROOTFS/tmp/vexim2

# system user for virtual mailboxes
lxc-attach -n $MACH -- \
    zsh -c \
    'adduser --system --home /var/vmail --disabled-password --disabled-login \
             --group --uid 500 vexim'
VEXIM_UID=$(lxc-attach -n $MACH -- grep vexim /etc/passwd | cut -d':' -f3)
VEXIM_GID=$(lxc-attach -n $MACH -- grep vexim /etc/passwd | cut -d':' -f4)

# vexim database
VEXIM_DB_PASSWD=`(echo -n $RANDOM$RANDOM; cat /proc/sys/kernel/random/uuid) | \
    sha256sum | cut -c 1-20`

lxc-attach -n $MACH -- mysql <<EOF
CREATE DATABASE vexim DEFAULT CHARACTER SET utf8;
CREATE USER 'vexim'@'localhost';
SET PASSWORD FOR 'vexim'@'localhost' = PASSWORD('$VEXIM_DB_PASSWD');
GRANT SELECT,INSERT,DELETE,UPDATE ON vexim.* to 'vexim'@'localhost';
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
    "sed -i 's/\(\s*\)\$sqlpass\s*=.*$/\1\$sqlpass = \"$VEXIM_DB_PASSWD\";/' \
         /var/www/html/vexim/config/variables.php
     sed -i 's/\(\s*\)\$uid\s*=.*$/\1\$uid = \"$VEXIM_UID\";/' \
         /var/www/html/vexim/config/variables.php
     sed -i 's/\(\s*\)\$gid\s*=.*$/\1\$gid = \"$VEXIM_GID\";/' \
         /var/www/html/vexim/config/variables.php
     sed -i 's/\(\s*\)\(\$passwordstrengthcheck\)\s*=.*$/\1\2 = 0;/' \
         /var/www/html/vexim/config/variables.php"

# customization for exim4
cp -r etc/exim4/conf.d/*  $ROOTFS/etc/exim4/conf.d/

lxc-attach -n $MACH -- \
    zsh -c \
    "sed -i 's/CHANGE/$VEXIM_DB_PASSWD/' \
         /etc/exim4/conf.d/main/00_vexim_listmacrosdefs
     update-exim4.conf"

# remove vexim2 repo
rm -rf $ROOTFS/tmp/vexim2

# -----------------------------------------------------------------------------
# APACHE2
# -----------------------------------------------------------------------------
cp var/www/html/index.html $ROOTFS/var/www/html/
cp etc/apache2/conf-available/servername.conf \
    $ROOTFS/etc/apache2/conf-available/
cp etc/apache2/sites-available/000-default.conf \
    $ROOTFS/etc/apache2/sites-available/

lxc-attach -n $MACH -- \
    zsh -c \
    "sed -i 's/ssl-cert-snakeoil/ssl-ej-email/' \
         /etc/apache2/sites-available/default-ssl.conf"

lxc-attach -n $MACH -- a2ensite default-ssl.conf
lxc-attach -n $MACH -- a2enconf servername
lxc-attach -n $MACH -- a2enmod ssl
lxc-attach -n $MACH -- a2enmod rewrite

# -----------------------------------------------------------------------------
# DOVECOT
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- \
    zsh -c \
    "sed -i 's/^!include auth-system.conf.ext/#!include auth-system.conf.ext/' \
         /etc/dovecot/conf.d/10-auth.conf
     sed -i 's/^#!include auth-sql.conf.ext/!include auth-sql.conf.ext/' \
         /etc/dovecot/conf.d/10-auth.conf
     sed -i 's/^mail_location\s*=.*$/mail_location = maildir:~\/Maildir/' \
         /etc/dovecot/conf.d/10-mail.conf
     sed -i 's/^\(ssl\s*=\s*no\)/#\1/' \
         /etc/dovecot/conf.d/10-ssl.conf
     sed -i '/\s*mailbox Drafts {/a \    auto = subscribe' \
         /etc/dovecot/conf.d/15-mailboxes.conf
     sed -i '/\s*mailbox Junk {/a \    auto = subscribe' \
         /etc/dovecot/conf.d/15-mailboxes.conf
     sed -i '/\s*mailbox Trash {/a \    auto = subscribe' \
         /etc/dovecot/conf.d/15-mailboxes.conf
     sed -i '/\s*mailbox Sent {/a \    auto = subscribe' \
         /etc/dovecot/conf.d/15-mailboxes.conf"

lxc-attach -n $MACH -- \
    zsh -c \
    "cat >> /etc/dovecot/dovecot-sql.conf.ext <<EOF

driver = mysql
default_pass_scheme = CRYPT
connect = host=/var/run/mysqld/mysqld.sock dbname=vexim user=vexim password=$VEXIM_DB_PASSWD

password_query = \\\\
    SELECT username AS user, crypt AS password \\\\
    FROM users \\\\
    WHERE username = '%u' AND enabled = 1
user_query = \\\\
    SELECT pop AS home, uid, gid \\\\
    FROM users \\\\
    WHERE username = '%u'
iterate_query = \\\\
    SELECT username AS user \\\\
    FROM users
EOF"

lxc-attach -n $MACH -- \
    zsh -c \
    "cat >> /etc/dovecot/conf.d/10-ssl.conf <<EOF

ssl = required
ssl_cert = </etc/ssl/certs/ssl-ej-email.pem
ssl_key = </etc/ssl/private/ssl-ej-email.key
EOF"

# -----------------------------------------------------------------------------
# ROUNDCUBE
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- \
    zsh -c \
    "sed -i 's/^#\s*\(Alias \/roundcube.*\)$/\1/' /etc/roundcube/apache.conf
     sed -i \"s/^\(\\\$config\['default_host'\]\)\s*=.*$/\1 = '127.0.0.1';/\" \
         /etc/roundcube/config.inc.php
     sed -i \"s/^\(\s*\)'zipdownload',/\1'zipdownload',\n\1'managesieve',/\" \
         /etc/roundcube/config.inc.php
     sed -i \"s/^\(\\\$config\['session_lifetime'\]\)\s*=.*$/\1 = 60;/\" \
         /etc/roundcube/defaults.inc.php"

lxc-attach -n $MACH -- \
    zsh -c \
    'cp /usr/share/roundcube/plugins/managesieve/config.inc.php.dist \
         /etc/roundcube/plugins/managesieve/config.inc.php'

# -----------------------------------------------------------------------------
# IPTABLES RULES
# -----------------------------------------------------------------------------
# public ssh
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport $SSH_PORT -j DNAT --to $IP:22 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport $SSH_PORT -j DNAT --to $IP:22
# smtp
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 25 -j DNAT --to $IP:25 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 25 -j DNAT --to $IP:25
# smtp (starttls)
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 587 -j DNAT --to $IP:587 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 587 -j DNAT --to $IP:587
# pop3
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 110 -j DNAT --to $IP:110 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 110 -j DNAT --to $IP:110
# pop3s
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 995 -j DNAT --to $IP:995 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 995 -j DNAT --to $IP:995
# imap
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 143 -j DNAT --to $IP:143 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 143 -j DNAT --to $IP:143
# imaps
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 993 -j DNAT --to $IP:993 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 993 -j DNAT --to $IP:993
# web panel
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 80 -j DNAT --to $IP:80 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 80 -j DNAT --to $IP:80
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 443 -j DNAT --to $IP:443 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 443 -j DNAT --to $IP:443

# -----------------------------------------------------------------------------
# CONTAINER SERVICES
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- systemctl reload apache2.service
lxc-attach -n $MACH -- systemctl restart spamassassin.service
lxc-attach -n $MACH -- systemctl restart clamav-daemon.service
lxc-attach -n $MACH -- systemctl restart exim4.service
lxc-attach -n $MACH -- systemctl restart dovecot.service

lxc-attach -n $MACH -- reboot
lxc-wait -n $MACH -s RUNNING
