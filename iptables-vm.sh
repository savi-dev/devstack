#!/bin/bash

MYIP=10.100.10.1
sudo ifconfig br-ex $MYIP/24 up
sudo ifconfig br-ex mtu 1300
MYIP=`/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`

sudo ip route add 192.168.0.0/16 via 10.100.10.2
sudo iptables -t nat -A POSTROUTING -s 10.100.10.0/24 -o eth0 -j SNAT --to-source $MYIP
