#!/bin/bash

# -----------------------------------------------------------------------------
# EJ-BASE.SH
# -----------------------------------------------------------------------------
export INSTALLER="ej-base"
export CONFIG_FILE="${INSTALLER}.conf"
export FREE_SPACE_NEEDED="1000000"

export START_TIME=`date +%s`
export DATE=`date +"%Y%m%d%H%M%S"`
export GIT_REPO="https://github.com/emrahcom/emrah-jessie.git"
export GIT_LOCAL_DIR="emrah-jessie"
export RELEASE="jessie"
export BASEDIR=`pwd`

export BRIDGE="ej0"

# -----------------------------------------------------------------------------
# CUSTOMIZATION
# -----------------------------------------------------------------------------
# Please set the related environment variables in CONFIG_FILE to prevent to run
# some scripts or to prevent to check some criteria during the installation.
#
# Examples:
#		export DONT_CLONE_GIT_REPO=true
#		export DONT_RUN_HOST=true
#		export DONT_RUN_JESSIE=true
#		export BRIDGE="br0"
# -----------------------------------------------------------------------------
[ -e "$BASEDIR/$CONFIG_FILE" ] && source "$BASEDIR/$CONFIG_FILE"



# -----------------------------------------------------------------------------
# CHECKING THE HOST (which will host the LXC containers)
# -----------------------------------------------------------------------------
# If the current user is not 'root', cancel the installation.
if [ "root" != "`whoami`" ]
then
	echo
	echo "ERROR: unauthorized user"
	echo "Please, run the installation script as 'root'"
	exit 1
fi

# If the OS release is unsupported, cancel the installation.
if [ "$DONT_CHECK_OS_RELEASE" != true \
     -a -z "$(grep $RELEASE /etc/os-release)" ]
then
	echo
	echo "ERROR: unsupported OS release"
	echo "Please, use '$RELEASE' on host machine"
	exit 1
fi

# If there is not enough disk free space, cancel the installation.
FREE=`(df | grep "/var/lib/lxc$"
        df | grep "/var/lib$"
        df | grep "/var$"
        df | egrep "/$") | \
        head -n1 | awk '{ print $4; }'`
if [ "$DONT_CHECK_FREE_SPACE" != true \
     -a "$FREE" -lt "$FREE_SPACE_NEEDED" ]
then
	echo
	echo "ERROR: there is not enough disk free space"
	echo
	df -h
	exit 1
fi



set -e

# -----------------------------------------------------------------------------
# CLONING THE GIT REPO
# -----------------------------------------------------------------------------
if [ "$DONT_CLONE_GIT_REPO" != true ]
then
	apt-get update
	apt-get install -y git

	rm -rf $GIT_LOCAL_DIR
	git clone --depth=1 $GIT_REPO $GIT_LOCAL_DIR
fi



# -----------------------------------------------------------------------------
# RUNNING THE SUB INSTALLATION SCRIPTS
# -----------------------------------------------------------------------------
cd $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER

for sub in `ls *.sh`
do
	bash $sub
done



# -----------------------------------------------------------------------------
# INSTALLATION DURATION
# -----------------------------------------------------------------------------
END_TIME=`date +%s`
DURATION=`date -u -d "0 $END_TIME seconds - $START_TIME seconds" +"%H:%M:%S"`

echo Installation Duration: $DURATION