#!/bin/bash

# -----------------------------------------------------------------------------
# PRE_LIVESTREAM_ORIGIN.SH
# -----------------------------------------------------------------------------
set -e
source $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source
[ "$DONT_RUN_PRE_LIVESTREAM_ORIGIN" = true ] && exit

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
MACH="ej-livestream-origin"

echo
echo "------------------------ pre $MACH ------------------------"

# -----------------------------------------------------------------------------
# COMPILING NGINX WITH NGINX-RTMP-MODULE
# -----------------------------------------------------------------------------
# start the compiler container
lxc-start -d -n ej-compiler
lxc-wait -n ej-compiler -s RUNNING

# packages
lxc-attach -n ej-compiler -- \
    zsh -c \
    'export DEBIAN_FRONTEND=noninteractive
     apt-get install -y ffmpeg
     apt-get build-dep -y nginx'

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
