#!/bin/bash

# -----------------------------------------------------------------------------
# PASSWORD_VEXIM.SH
# -----------------------------------------------------------------------------
set -e
source $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source
[ "$DONT_RUN_PASSWORD" = true ] && exit

if [ "$DONT_RUN_EMAIL" != true ]
then
    echo "Vexim web account: $VEXIM_WEB_USER / $VEXIM_WEB_PASSWD"
fi
