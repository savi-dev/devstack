#!/bin/bash

. ~/devstack/openrc
export OS_PASSWORD=mysecret

. ~/vars.env

keystone user-password-update --pass $ADMIN_PASS admin

export OS_PASSWORD=$ADMIN_PASS

for u in ceilometer cinder demo glance neutron nova swift swiftusertest1 swiftusertest2 swiftusertest3; do
   keystone user-password-update --pass $ADMIN_PASS $u
done
