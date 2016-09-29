#!/bin/bash

# -----------------------------------------------------------------------------
# DELETE_INSTALLER.SH
# -----------------------------------------------------------------------------
set -e
[ "$DONT_RUN_DELETE_INSTALLER" = true ] && exit

# remove installer and git repo.
cd $BASEDIR
rm -f ${INSTALLER}.sh
rm -rf $GIT_LOCAL_DIR
