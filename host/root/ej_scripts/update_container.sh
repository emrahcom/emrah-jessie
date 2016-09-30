#!/bin/bash

for mach in `lxc-ls -f | egrep 'RUNNING\s.*\sYES\s.*ej-group' | cut -d ' ' -f1`
do
	echo
	echo "<<<" $mach ">>>"
	echo

	lxc-attach -n $mach -- /root/ej_scripts/update_debian.sh
done
