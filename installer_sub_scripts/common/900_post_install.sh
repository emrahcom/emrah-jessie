#!/bin/bash

# -----------------------------------------------------------------------------
# POST_INSTALL.SH
# -----------------------------------------------------------------------------
set -e
[ "$DONT_RUN_POST_INSTALL" = true ] && exit

echo
echo "-------------------- POST INSTALL --------------------"

# iptables
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6
