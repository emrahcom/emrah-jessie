#!/bin/bash

# -----------------------------------------------------------------------------
# JESSIE.SH
# -----------------------------------------------------------------------------
set -e
source $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source
[ "$DONT_RUN_JESSIE" = true ] && exit



# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
MACH="ej-jessie"
ROOTFS="/var/lib/lxc/$MACH/rootfs"
DNS_RECORD=$(grep "address=/$MACH/" /etc/dnsmasq.d/ej_hosts | \
	     head -n1)
IP=${DNS_RECORD##*/}
echo JESSIE="$IP" >> \
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

# create the new one
lxc-create -n $MACH -t debian -P /var/lib/lxc/ -- -r jessie

# container config
sed -i '/lxc\.network\./d' /var/lib/lxc/$MACH/config
cat >> /var/lib/lxc/$MACH/config <<EOF

lxc.mount.entry = /var/cache/apt/archives \
/var/lib/lxc/$MACH/rootfs/var/cache/apt/archives none bind 0 0

lxc.network.type = veth
lxc.network.flags = up
lxc.network.link = $BRIDGE
lxc.network.name = $PUBLIC_INTERFACE
lxc.network.ipv4 = $IP/24
lxc.network.ipv4.gateway = auto
EOF
rm -rf $ROOTFS/var/cache/apt/archives
mkdir -p $ROOTFS/var/cache/apt/archives

# changed/added system files
echo nameserver $HOST > $ROOTFS/etc/resolv.conf
cp etc/network/interfaces $ROOTFS/etc/network/
cp etc/apt/sources.list $ROOTFS/etc/apt/
cp etc/apt/apt.conf.d/80recommends $ROOTFS/etc/apt/apt.conf.d/

# start container
lxc-start -d -n $MACH



# -----------------------------------------------------------------------------
# PACKAGES
# -----------------------------------------------------------------------------

# update
lxc-attach -n $MACH -- apt-get update
lxc-attach -n $MACH -- apt-get -y install debian-archive-keyring
lxc-attach -n $MACH -- apt-get update
lxc-attach -n $MACH -- apt-get -y dist-upgrade
lxc-attach -n $MACH -- apt-get autoclean

# packages
lxc-attach -n $MACH -- apt-get install -y less tmux vim wget zsh 
lxc-attach -n $MACH -- apt-get install -y openssh-server openssh-client
lxc-attach -n $MACH -- apt-get install -y dnsutils curl htop bmon bwm-ng
lxc-attach -n $MACH -- apt-get install -y rsync bzip2 man ack-grep
lxc-attach -n $MACH -- apt-get install -y cron logrotate
lxc-attach -n $MACH -- apt-get install -y dbus libpam-systemd



# -----------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# -----------------------------------------------------------------------------

# changed/added system files
cp /etc/hosts $ROOTFS/etc/
cp etc/ssh/ssh_config $ROOTFS/etc/ssh/
cp etc/ssh/sshd_config $ROOTFS/etc/ssh/



# -----------------------------------------------------------------------------
# ROOT USER
# -----------------------------------------------------------------------------

# shell
lxc-attach -n $MACH -- chsh -s /bin/zsh root
cp root/.bashrc $ROOTFS/root/
cp root/.vimrc $ROOTFS/root/
cp root/.zshrc $ROOTFS/root/

# ssh
if [ -f /root/.ssh/authorized_keys ]
then
    mkdir $ROOTFS/root/.ssh
    cp /root/.ssh/authorized_keys $ROOTFS/root/.ssh/
    chmod 700 $ROOTFS/root/.ssh
    chmod 600 $ROOTFS/root/.ssh/authorized_keys
fi

# scripts
mkdir $ROOTFS/root/scripts
cp root/scripts/update_debian.sh $ROOTFS/root/scripts/
cp root/scripts/upgrade_debian.sh $ROOTFS/root/scripts/
chmod 744 $ROOTFS/root/scripts/update_debian.sh
chmod 744 $ROOTFS/root/scripts/upgrade_debian.sh



# -----------------------------------------------------------------------------
# CONTAINER SERVICES
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- poweroff
lxc-wait -n $MACH -s STOPPED
