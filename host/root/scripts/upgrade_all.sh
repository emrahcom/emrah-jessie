#!/bin/bash

echo
echo "<<< HOST >>>"
echo
/root/scripts/upgrade_debian.sh

echo
echo "<<< CONTAINERS >>>"
echo
/root/scripts/upgrade_container.sh
