#!/bin/bash

# -----------------------------------------------------------------------------
# LIVESTREAM_ORIGIN.SH
# -----------------------------------------------------------------------------
set -e
source $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source
[ "$DONT_RUN_LIVESTREAM_ORIGIN" = true ] && exit

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
MACH="ej-livestream-origin"
ROOTFS="/var/lib/lxc/$MACH/rootfs"
DNS_RECORD=$(grep "address=/$MACH/" /etc/dnsmasq.d/ej_hosts | head -n1)
IP=${DNS_RECORD##*/}
SSH_PORT="30${IP##*.}"
echo LIVESTREAM_ORIGIN="$IP" >> \
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
cp -arp $BASEDIR/$GIT_LOCAL_DIR/host/usr/local/ej/livestream $SHARED/
chown www-data:www-data $SHARED/livestream -R

# container config
rm -rf $ROOTFS/var/cache/apt/archives
mkdir -p $ROOTFS/var/cache/apt/archives
rm -rf $ROOTFS/usr/local/ej/deb
mkdir -p $ROOTFS/usr/local/ej/deb
rm -rf $ROOTFS/usr/local/ej/livestream
mkdir -p $ROOTFS/usr/local/ej/livestream
sed -i '/\/var\/cache\/apt\/archives/d' /var/lib/lxc/$MACH/config
sed -i '/lxc\.network\./d' /var/lib/lxc/$MACH/config
cat >> /var/lib/lxc/$MACH/config <<EOF

lxc.start.auto = 1
lxc.start.order = 600
lxc.start.delay = 2
lxc.group = ej-group
lxc.group = onboot

lxc.mount.entry = /var/cache/apt/archives \
$ROOTFS/var/cache/apt/archives none bind 0 0
lxc.mount.entry = $SHARED/deb $ROOTFS/usr/local/ej/deb none bind 0 0
lxc.mount.entry = $SHARED/livestream \
$ROOTFS/usr/local/ej/livestream none bind 0 0

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
# COMPILING
# -----------------------------------------------------------------------------
# start the compiler container
lxc-start -d -n ej-compiler
lxc-wait -n ej-compiler -s RUNNING

# packages
lxc-attach -n ej-compiler -- \
    zsh -c \
    'export DEBIAN_FRONTEND=noninteractive
     apt-get install -y ffmpeg
     apt-get build-dep -y nginx-extras'

# nginx RTMP module
REPO="https://github.com/sergey-dryabzhinsky/nginx-rtmp-module/archive"
ZIP="master.zip"
lxc-attach -n ej-compiler -- \
    zsh -c \
    "export DEBIAN_FRONTEND=noninteractive
     mkdir -p /root/source
     cd /root/source
     rm -rf nginx_* nginx-*
     apt-get source nginx-extras
     wget --no-check-certificate $REPO/$ZIP -O $ZIP
     unzip master.zip
     mv nginx-rtmp-module-master nginx-1.6.2/debian/modules/nginx-rtmp-module
     sed -i '/nginx-upstream-fair/a \
         \\\\t\t\t--add-module=\$(MODULESDIR)\/nginx-rtmp-module \\\\' \
	 /root/source/nginx-1.6.2/debian/rules
     cd nginx-1.6.2
     cp debian/modules/nginx-rtmp-module/stat.xsl \
         debian/help/examples/rtmp_stat.xsl
     dpkg-buildpackage -rfakeroot -uc -b
     cd ..
     mv nginx-common_*.deb nginx-full_* nginx-extras_*.deb nginx-doc_*.deb \
         /usr/local/ej/deb/"

# stop the compiler container
lxc-stop -n ej-compiler
lxc-wait -n ej-compiler -s STOPPED

# -----------------------------------------------------------------------------
# PACKAGES
# -----------------------------------------------------------------------------
# multimedia repo
cp etc/apt/sources.list.d/multimedia.list $ROOTFS/etc/apt/sources.list.d/
lxc-attach -n $MACH -- apt-get update
lxc-attach -n $MACH -- apt-get install -y --force-yes deb-multimedia-keyring

# update
lxc-attach -n $MACH -- apt-get update
lxc-attach -n $MACH -- apt-get -y dist-upgrade
lxc-attach -n $MACH -- apt-get autoclean

# packages
lxc-attach -n $MACH -- \
    zsh -c \
    "export DEBIAN_FRONTEND=noninteractive
     apt-get install -y iputils-ping
     apt-get install -y libgd3 libluajit-5.1-2 libperl5.20 libxslt1.1
     apt-get install -y ffmpeg
     apt-get install -y gstreamer1.0-tools gstreamer1.0-plugins-base \
         gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly \
	 gstreamer1.0-plugins-bad libgstreamer1.0-0 \
	 libgstreamer-plugins-base1.0-0 libgstreamer-plugins-bad1.0-0 \
	 gstreamer1.0-libav gstreamer1.0-alsa gstreamer1.0-x
     dpkg -i /usr/local/ej/deb/nginx-common_*.deb
     dpkg -i /usr/local/ej/deb/nginx-extras_*.deb
     dpkg -i /usr/local/ej/deb/nginx-doc_*.deb
     apt-mark hold nginx-common nginx-extras nginx-doc
     mkdir -p /usr/local/ej/livestream/stat/
     gunzip -c /usr/share/doc/nginx-doc/examples/rtmp_stat.xsl.gz > \
         /usr/local/ej/livestream/stat/rtmp_stat.xsl
     chown www-data: /usr/local/ej/livestream/stat -R"

# -----------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# -----------------------------------------------------------------------------
cp etc/cron.d/ej_hls_cleanup $ROOTFS/etc/cron.d/
cp etc/nginx/nginx.conf $ROOTFS/etc/nginx/
cp etc/nginx/conf.d/custom.conf $ROOTFS/etc/nginx/conf.d/
cp etc/nginx/sites-available/default $ROOTFS/etc/nginx/sites-available/

cp root/ej_scripts/livestream_cleanup.sh $ROOTFS/root/ej_scripts/
cp root/ej_scripts/livestream_test.sh $ROOTFS/root/ej_scripts/
chmod u+x $ROOTFS/root/ej_scripts/livestream_cleanup.sh
chmod u+x $ROOTFS/root/ej_scripts/livestream_test.sh

# -----------------------------------------------------------------------------
# IPTABLES RULES
# -----------------------------------------------------------------------------
# public ssh
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport $SSH_PORT -j DNAT --to $IP:22 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport $SSH_PORT -j DNAT --to $IP:22

# rtmp
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 1935 -j DNAT --to $IP:1935 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 1935 -j DNAT --to $IP:1935

# http from a private port
iptables -t nat -C PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 10080 -j DNAT --to $IP:80 || \
iptables -t nat -A PREROUTING ! -d $HOST -i $PUBLIC_INTERFACE -p tcp --dport 10080 -j DNAT --to $IP:80

# -----------------------------------------------------------------------------
# CONTAINER SERVICES
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- systemctl reload nginx

lxc-attach -n $MACH -- reboot
lxc-wait -n $MACH -s RUNNING
