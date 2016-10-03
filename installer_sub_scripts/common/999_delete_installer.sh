#!/bin/bash

# -----------------------------------------------------------------------------
# DELETE_INSTALLER.SH
# -----------------------------------------------------------------------------
set -e
[ "$DONT_RUN_DELETE_INSTALLER" = true ] && exit

# remove the git local repo.
cd $BASEDIR
rm -rf $GIT_LOCAL_DIR
