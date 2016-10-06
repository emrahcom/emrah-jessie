#!/bin/bash

# -----------------------------------------------------------------------------
# POST_INSTALL_IPTABLES.SH
# -----------------------------------------------------------------------------
set -e
[ "$DONT_RUN_POST_INSTALL" = true ] && exit

# iptables
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6
