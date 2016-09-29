#!/bin/bash

# -----------------------------------------------------------------------------
# NETWORK.SH
# -----------------------------------------------------------------------------
set -e
[ "$DONT_RUN_NETWORK" = true ] && exit



# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
echo
echo "-------------------- NETWORK --------------------"



# -----------------------------------------------------------------------------
# NETWORK CONFIG
# -----------------------------------------------------------------------------

# IP address
DNS_RECORD=$(grep 'address=/host/' /etc/dnsmasq.d/emrah-jessie-hosts | \
             head -n1)
IP=${DNS_RECORD##*/}
echo HOST="$IP" >> \
    $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source

# private bridge interface for the containers
EXISTS=$(brctl show | egrep "^$BRIDGE\s" || true)
[ -z "$EXISTS" ] && brctl addbr $BRIDGE
ifconfig $BRIDGE $IP netmask 255.255.255.0 up

# IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# iptables
iptables -F
iptables -F -t nat
iptables -A INPUT -d $IP -i $PUBLIC_INTERFACE -j DROP
iptables -t nat -A POSTROUTING -s 172.22.22.0/24 -o $BRIDGE -j MASQUERADE

# status
ip addr



# -----------------------------------------------------------------------------
# NETWORK RELATED SERVICES
# -----------------------------------------------------------------------------

# dnsmasq
systemctl stop dnsmasq.service
systemctl start dnsmasq.service
