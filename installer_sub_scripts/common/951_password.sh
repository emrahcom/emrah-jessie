#!/bin/bash

# -----------------------------------------------------------------------------
# PASSWORD.SH
# -----------------------------------------------------------------------------
set -e
source $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source
[ "$DONT_RUN_PASSWORD" = true ] && exit

echo
echo "-------------------- STATUS --------------------"

# -----------------------------------------------------------------------------
# POWERADMIN
# -----------------------------------------------------------------------------
if [ "$DONT_RUN_POWERDNS" != true ]; then
POWERADMIN_WEB_PASSWORD=$(egrep "^\$db_pass" \
  /var/lib/lxc/ej-powerdns/rootfs/var/www/html/poweradmin/inc/config.inc.php \
  | cut -d "'" -f2 | cut -c 1-20)
echo "Poweradmin   : admin / $POWERADMIN_WEB_PASSWORD"
fi

echo
