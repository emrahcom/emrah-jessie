#!/bin/bash

# -----------------------------------------------------------------------------
# PRE_WAF.SH
# -----------------------------------------------------------------------------
set -e
source $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source
[ "$DONT_RUN_PRE_WAF" = true ] && exit

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
MACH="ej-waf"

echo
echo "------------------------ pre $MACH ------------------------"

# -----------------------------------------------------------------------------
# PREPARING LUA-RESTY-WAF
# -----------------------------------------------------------------------------
# start the compiler container
lxc-start -d -n ej-compiler
lxc-wait -n ej-compiler -s RUNNING

# packages
lxc-attach -n ej-compiler -- \
    zsh -c \
    'export DEBIAN_FRONTEND=noninteractive
     apt-get install -y liblua5.1-0-dev luarocks libpcre3-dev'

# lua-resty-waf
lxc-attach -n ej-compiler -- \
    zsh -c \
    "mkdir -p /usr/local/ej/share/lua/5.1/resty
     mkdir -p /root/source

     cd /root/source
     git clone https://github.com/openresty/lua-resty-upload.git
     cd lua-resty-upload
     LUA_LIB_DIR=/usr/local/ej/share/lua/5.1 make install

     cd /root/source
     git clone https://github.com/openresty/lua-resty-dns.git
     cd lua-resty-dns
     LUA_LIB_DIR=/usr/local/ej/share/lua/5.1 make install

     cd /root/source
     git clone https://github.com/bungle/lua-resty-random.git
     cd lua-resty-random
     LUA_LIB_DIR=/usr/local/ej/share/lua/5.1 make install

     cd /root/source
     git clone https://github.com/openresty/lua-resty-string.git
     cd lua-resty-string
     LUA_LIB_DIR=/usr/local/ej/share/lua/5.1 make install

     cd /root/source
     git clone https://github.com/openresty/opm.git
     sed -i 's/\(if (\$name eq .luajit.) {\)/\1 return;/' opm/bin/opm
     mkdir opm/site

     cd /root/source
     git clone --recursive https://github.com/p0pr0ck5/lua-resty-waf.git
     cd lua-resty-waf
     make
     LUA_LIB_DIR=/usr/local/ej/share/lua/5.1 \
         OPENRESTY_PREFIX=/root/source/opm make install
     mv /usr/local/ej/share/lua/5.1/{libac,libinjection}.so \
         /usr/local/ej/share/lua/5.1/resty/
     cp -arp /root/source/opm/site/lualib/resty/* \
         /usr/local/ej/share/lua/5.1/resty/"

# stop the compiler container
lxc-stop -n ej-compiler
lxc-wait -n ej-compiler -s STOPPED
