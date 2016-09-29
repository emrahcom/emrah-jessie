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

# Private bridge interface for the containers
DNS_RECORD=$(grep 'address=/host/' /etc/dnsmasq.d/emrah-jessie-hosts | \
             head -n1)
HOST=${DNS_RECORD##*/}
EXISTS=$(brctl show | egrep "^$BRIDGE\s" || true)
[ -z "$EXISTS" ] && brctl addbr $BRIDGE
ifconfig $BRIDGE $HOST netmask 255.255.255.0 up

# IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# iptables
iptables -F
iptables -F -t nat
iptables -A INPUT -d $HOST -i $PUBLIC_INTERFACE -j DROP
iptables -t nat -A POSTROUTING -s 172.22.22.0/24 -o $BRIDGE -j MASQUERADE

# status
ip addr



# -----------------------------------------------------------------------------
# NETWORK RELATED SERVICES
# -----------------------------------------------------------------------------

# dnsmasq
systemctl stop dnsmasq.service
systemctl start dnsmasq.service
