#!/bin/bash

# -----------------------------------------------------------------------------
# POSTGRESQL.SH
# -----------------------------------------------------------------------------
set -e
source $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source
[ "$DONT_RUN_POWERDNS" = true ] && exit

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
MACH="ej-postgresql"
ROOTFS="/var/lib/lxc/$MACH/rootfs"
DNS_RECORD=$(grep "address=/$MACH/" /etc/dnsmasq.d/ej_hosts | head -n1)
IP=${DNS_RECORD##*/}
SSH_PORT="30${IP##*.}"
echo POSTGRESQL="$IP" >> \
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
lxc.start.order = 700
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
    zsh -c \
    'export DEBIAN_FRONTEND=noninteractive
     apt-get install -y iputils-ping
     apt-get install -y postgresql postgresql-contrib --install-recommends'

# -----------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# -----------------------------------------------------------------------------
sed -i "/^#listen_addresses/i \\
listen_addresses = '*'" $ROOTFS/etc/postgresql/9.4/main/postgresql.conf
cat etc/postgresql/9.4/main/ej_hba.conf >> \
    $ROOTFS/etc/postgresql/9.4/main/pg_hba.conf

# -----------------------------------------------------------------------------
# IPTABLES RULES
# -----------------------------------------------------------------------------
# public ssh
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport $SSH_PORT -j DNAT --to $IP:22 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport $SSH_PORT -j DNAT --to $IP:22

# -----------------------------------------------------------------------------
# CONTAINER SERVICES
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- reboot
lxc-wait -n $MACH -s RUNNING
