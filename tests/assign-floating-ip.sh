#!/bin/bash
# Two arguments expected:
#    1. Floating IP address
#    2. VM IP address (Could run into issues in future if different tenants use same private subnet addresses)
#

if [[ -n "$1" ]]; then
   FLOATING_IP=$1
else
   echo "Must specify first parameter (Floating IP address)"
   ERR=1
fi

if [[ -n "$2" ]]; then
   VM_IP=$2
else
   echo "Must specify second parameter (VM IP address)"
   ERR=1
fi

if [[ -z "$ERR" ]]; then
   TENANT_ID=`keystone token-get | grep tenant_id | awk '{print $4 }'`
   PORT_ID=`quantum port-list -c id -c fixed_ips -c tenant_id | grep $TENANT_ID | grep "$VM_IP" | awk '{print $2}'`
   FLOATING_IP_ID=`quantum floatingip-list | grep "$FLOATING_IP" | awk '{print $2}'`

   # disassociate whether it is associated or not, for safety.
   quantum floatingip-disassociate $FLOATING_IP_ID

   quantum floatingip-associate $FLOATING_IP_ID $PORT_ID

   quantum floatingip-list
fi

