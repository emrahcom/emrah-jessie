#!/bin/bash

# -----------------------------------------------------------------------------
# STATUS.SH
# -----------------------------------------------------------------------------
set -e
[ "$DONT_RUN_STATUS" = true ] && exit

echo
echo "-------------------- STATUS --------------------"

# Network
ip addr
echo

# LXC containers
lxc-ls -f
echo
