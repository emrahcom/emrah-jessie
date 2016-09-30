#!/bin/bash

# -----------------------------------------------------------------------------
# HOST.SH
# -----------------------------------------------------------------------------
set -e
[ "$DONT_RUN_HOST" = true ] && exit

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
cd $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER

echo
echo "-------------------- HOST --------------------"

# -----------------------------------------------------------------------------
# BACKUP & STATUS
# -----------------------------------------------------------------------------
OLD_FILES="/root/emrah_jessie_old_files/$DATE"
mkdir -p $OLD_FILES

# backup the files which will be changed
[ -f /etc/iptables/rules.v4 ] && cp /etc/iptables/rules.v4 $OLD_FILES/
[ -f /etc/iptables/rules.v6 ] && cp /etc/iptables/rules.v6 $OLD_FILES/
[ -f /etc/network/interfaces ] && cp /etc/network/interfaces $OLD_FILES/

# network status
echo "# ----- ip addr -----" >> $OLD_FILES/network.status
ip addr >> $OLD_FILES/network.status
echo >> $OLD_FILES/network.status
echo "# ----- ip route -----" >> $OLD_FILES/network.status
ip route >> $OLD_FILES/network.status

# iptables status
if [ -n "`command -v iptables`" ]
then
	echo "# ----- iptables -nv -L -----" >> $OLD_FILES/iptables.status
	iptables -nv -L >> $OLD_FILES/iptables.status
	echo "# ----- iptables -nv -L -t nat -----" >> $OLD_FILES/iptables.status
	iptables -nv -L -t nat >> $OLD_FILES/iptables.status
fi

# process status
echo "# ----- ps auxfw -----" >> $OLD_FILES/ps.status
ps auxfw >> $OLD_FILES/ps.status

# Deb status
echo "# ----- dpkg -l -----" >> $OLD_FILES/dpkg.status
dpkg -l >> $OLD_FILES/dpkg.status

# -----------------------------------------------------------------------------
# PACKAGES
# -----------------------------------------------------------------------------
# repo update & upgrade
apt-get update
apt-get -dy dist-upgrade
apt-get -y upgrade

# debconf
debconf-set-selections <<< \
    'iptables-persistent iptables-persistent/autosave_v4 boolean false'
debconf-set-selections <<< \
    'iptables-persistent iptables-persistent/autosave_v6 boolean false'

# added packages
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
apt-get install -y zsh tmux vim
apt-get install -y cron
apt-get install -y bridge-utils
apt-get install -y lxc debootstrap
apt-get install -y htop iotop bmon bwm-ng
apt-get install -y iputils-ping fping wget curl whois dnsutils
apt-get install -y bzip2 rsync ack-grep
apt-get install -y openntpd dnsmasq

# -----------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# -----------------------------------------------------------------------------
# changed/added system files
cp ../../host/etc/cron.d/ej_update /etc/cron.d/
cp ../../host/etc/sysctl.d/ej_ip_forward.conf /etc/sysctl.d/
cp ../../host/etc/network/interfaces.d/ej_bridge /etc/network/interfaces.d/
cp ../../host/etc/dnsmasq.d/ej_interface /etc/dnsmasq.d/
cp ../../host/etc/dnsmasq.d/ej_hosts /etc/dnsmasq.d/

sed -i "s/#BRIDGE#/${BRIDGE}/g" /etc/network/interfaces.d/ej_bridge
sed -i "s/#BRIDGE#/${BRIDGE}/g" /etc/dnsmasq.d/ej_interface

[ -z "$(egrep '^source-directory\s*interfaces.d' /etc/network/interfaces || true)" ] && \
[ -z "$(egrep '^source-directory\s*/etc/network/interfaces.d' /etc/network/interfaces || true)" ] && \
[ -z "$(egrep '^source\s*interfaces.d/\*' /etc/network/interfaces || true)" ] && \
[ -z "$(egrep '^source\s*/etc/network/interfaces.d/\*' /etc/network/interfaces || true)" ] && \
[ -z "$(egrep '^source\s*interfaces.d/ej_bridge' /etc/network/interfaces || true)" ] && \
[ -z "$(egrep '^source\s*/etc/network/interfaces.d/ej_bridge' /etc/network/interfaces || true)" ] && \
echo -e "\nsource /etc/network/interfaces.d/ej_bridge" >> /etc/network/interfaces

# sysctl.d
sysctl -p

# -----------------------------------------------------------------------------
# ROOT USER
# -----------------------------------------------------------------------------
# added directories
mkdir -p /root/ej_scripts

# changed/added files
cp ../../host/root/ej_scripts/update_debian.sh /root/ej_scripts/
cp ../../host/root/ej_scripts/update_container.sh /root/ej_scripts/
cp ../../host/root/ej_scripts/upgrade_debian.sh /root/ej_scripts/
cp ../../host/root/ej_scripts/upgrade_container.sh /root/ej_scripts/
cp ../../host/root/ej_scripts/upgrade_all.sh /root/ej_scripts/

# file permissons
chmod u+x /root/ej_scripts/update_debian.sh
chmod u+x /root/ej_scripts/update_container.sh
chmod u+x /root/ej_scripts/upgrade_debian.sh
chmod u+x /root/ej_scripts/upgrade_container.sh
chmod u+x /root/ej_scripts/upgrade_all.sh
