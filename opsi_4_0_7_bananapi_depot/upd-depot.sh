#!/bin/bash
LANIF=eth0							# main LAN interface to listen to

/usr/bin/opsi-setup --ip-address $(ifconfig $LANIF | grep "inet Adresse" | cut -d ":" -f 2 | cut -d " " -f 1) --init-current-config

exit 0
