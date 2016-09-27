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
OLD_FILES="/root/$INSTALLER/old_files_$DATE"
mkdir -p $OLD_FILES

# backup
cp /etc/apt/sources.list $OLD_FILES/
cp /etc/crontab $OLD_FILES/

# Network status
echo "# ----- ip addr -----" >> $OLD_FILES/network.status
ip addr >> $OLD_FILES/network.status
echo >> $OLD_FILES/network.status
echo "# ----- ip route -----" >> $OLD_FILES/network.status
ip route >> $OLD_FILES/network.status

# iptables status
echo "# ----- iptables -nv -L -----" >> $OLD_FILES/iptables.status
iptables -nv -L >> $OLD_FILES/iptables.status
echo "# ----- iptables -nv -L -t nat -----" >> $OLD_FILES/iptables.status
iptables -nv -L -t nat >> $OLD_FILES/iptables.status

# Process status
echo "# ----- ps auxfw -----" >> $OLD_FILES/ps.status
ps auxfw >> $OLD_FILES/ps.status

# Deb status
echo "# ----- dpkg -l -----" >> $OLD_FILES/dpkg.status
dpkg -l >> $OLD_FILES/dpkg.status




# -----------------------------------------------------------------------------
# PACKAGES
# -----------------------------------------------------------------------------

# repo config
cp ../../host/etc/apt/sources.list /etc/apt/
cp ../../host/etc/apt/apt.conf.d/80recommends /etc/apt/apt.conf.d/

apt-get update
apt-get autoclean
apt-get purge -y apt-listchanges
apt-get -dy dist-upgrade
apt-get -y dist-upgrade

# removed packages
apt-get purge -y nfs-common rpcbind installation-report reportbug
apt-get purge -y tasksel tasksel-data task-english os-prober
apt-get purge -y aptitude
DEBIAN_FRONTEND=noninteractive apt-get purge -y resolvconf
apt-get install -y openssh-server openssh-sftp-server
apt-get autoremove -y

# debconf
debconf-set-selections <<< \
    'iptables-persistent iptables-persistent/autosave_v4 boolean false'
debconf-set-selections <<< \
    'iptables-persistent iptables-persistent/autosave_v6 boolean false'

# added packages
apt-get install -y zsh tmux vim
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
apt-get install -y bridge-utils
apt-get install -y lxc debootstrap
apt-get install -y htop iotop bmon bwm-ng
apt-get install -y iputils-ping fping whois curl dnsutils
apt-get install -y bzip2 zip unzip patch tree
apt-get install -y rsync ack-grep jq
apt-get install -y openntpd dnsmasq



# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------

# changed/added system files
cp ../../host/etc/crontab /etc/
cp ../../host/etc/sysctl.d/emrah-jessie.conf /etc/sysctl.d/
cp ../../host/etc/network/interfaces.d/emrah-jessie /etc/network/interfaces.d/

sysctl -p



# -----------------------------------------------------------------------------
# ROOT USER
# -----------------------------------------------------------------------------
chsh -s /bin/zsh root

# changed directories
mkdir -p /root/scripts

# changed files
cp ../../host/root/.vimrc /root/
cp ../../host/root/.zshrc /root/
cp ../../host/root/scripts/update_debian.sh /root/scripts/
cp ../../host/root/scripts/update_container.sh /root/scripts/
cp ../../host/root/scripts/upgrade_debian.sh /root/scripts/
cp ../../host/root/scripts/upgrade_container.sh /root/scripts/
cp ../../host/root/scripts/upgrade_all.sh /root/scripts/

# file permissons
chmod u+x /root/scripts/update_debian.sh
chmod u+x /root/scripts/update_container.sh
chmod u+x /root/scripts/upgrade_debian.sh
chmod u+x /root/scripts/upgrade_container.sh
chmod u+x /root/scripts/upgrade_all.sh
