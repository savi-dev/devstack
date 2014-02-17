#!/bin/bash

TOP_DIR=~/devstack

source $TOP_DIR/localrc

for i in $HOME/.ssh/id_rsa.pub $HOME/.ssh/id_dsa.pub; do
    if [[ -r $i ]]; then
        nova keypair-add --pub_key=$i `hostname`
        break
    fi
done

# Add tcp/22 and icmp to default security group
source $TOP_DIR/openrc admin demo1 $REGION_NAME
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
source $TOP_DIR/openrc admin demo2 $REGION_NAME
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0

