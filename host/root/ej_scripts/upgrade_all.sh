#!/bin/bash

echo
echo "<<< HOST >>>"
echo
/root/ej_scripts/upgrade_debian.sh

echo
echo "<<< CONTAINERS >>>"
echo
/root/ej_scripts/upgrade_container.sh
