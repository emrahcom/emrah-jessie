#!/bin/bash

# -----------------------------------------------------------------------------
# PASSWORD.SH
# -----------------------------------------------------------------------------
set -e
source $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source
[ "$DONT_RUN_PASSWORD" = true ] && exit

echo
echo "------------------------- PASSWORD -------------------------"
