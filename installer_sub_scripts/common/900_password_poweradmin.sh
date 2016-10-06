#!/bin/bash

# -----------------------------------------------------------------------------
# PASSWORD_POWERADMIN.SH
# -----------------------------------------------------------------------------
set -e
source $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source
[ "$DONT_RUN_PASSWORD" = true ] && exit

if [ "$DONT_RUN_POWERDNS" != true ]
then
    POWERADMIN_WEB_PASSWORD=$(grep "^\$db_pass" \
        /var/lib/lxc/ej-powerdns/rootfs/var/www/html/poweradmin/inc/config.inc.php \
        | cut -d "'" -f2 | cut -c 1-20)
    echo "Poweradmin   : admin / $POWERADMIN_WEB_PASSWORD"
fi
