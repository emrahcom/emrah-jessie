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
echo "------------------------- NETWORK --------------------------"

# -----------------------------------------------------------------------------
# NETWORK CONFIG
# -----------------------------------------------------------------------------
# public interface
DEFAULT_ROUTE=$(ip route | egrep '^default ' | head -n1)
PUBLIC_INTERFACE=${DEFAULT_ROUTE##*dev }
PUBLIC_INTERFACE=${PUBLIC_INTERFACE/% */}
echo PUBLIC_INTERFACE="$PUBLIC_INTERFACE" >> \
    $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source

# IP address
DNS_RECORD=$(grep 'address=/host/' /etc/dnsmasq.d/ej_hosts | head -n1)
IP=${DNS_RECORD##*/}
echo HOST="$IP" >> \
    $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source

# private bridge interface for the containers
EXISTS=$(brctl show | egrep "^$BRIDGE\s" || true)
[ -z "$EXISTS" ] && brctl addbr $BRIDGE
ifconfig $BRIDGE $IP netmask 255.255.255.0 up

# IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# -----------------------------------------------------------------------------
# IPTABLES
# -----------------------------------------------------------------------------
# drop packets coming from the public interface to private IP
iptables -C INPUT -d $IP -i $PUBLIC_INTERFACE -j DROP || \
iptables -A INPUT -d $IP -i $PUBLIC_INTERFACE -j DROP

# masquerade packets coming from the private network
iptables -t nat -C POSTROUTING -s 172.22.22.0/24 -o $PUBLIC_INTERFACE -j MASQUERADE || \
iptables -t nat -A POSTROUTING -s 172.22.22.0/24 -o $PUBLIC_INTERFACE -j MASQUERADE

# -----------------------------------------------------------------------------
# NETWORK RELATED SERVICES
# -----------------------------------------------------------------------------
# dnsmasq
systemctl stop dnsmasq.service
systemctl start dnsmasq.service

# -----------------------------------------------------------------------------
# STATUS
# -----------------------------------------------------------------------------
ip addr
