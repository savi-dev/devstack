#!/bin/bash

. ./openrc
glance image-delete 5b699a4e-daa9-40c5-94e5-5d71a9b75406 c385308e-054b-4af2-a5d5-b975bfe1c0d9 b1959704-9543-466b-8bab-f141c1f30359
wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
glance image-create --name cirros --public --container-format bare --disk-format qcow2 < ./cirros-0.3.4-x86_64-disk.img
wget https://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-uefi1.img
glance image-create --name ubuntu --public --container-format bare --disk-format qcow2 < ./trusty-server-cloudimg-amd64-uefi1.img

