#!/bin/bash

MYIP=`/sbin/ifconfig br-ex | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`

#sudo ifconfig br-ex 10.10.10.1/24 up
#sudo ifconfig br-ex mtu 1400
#sudo ip route add 10.20.0.0/16 via 130.127.135.2 
#sudo iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o eth0 -j SNAT --to-source $MYIP
QR=qrouter-71a89515-8d38-4632-aa05-2ea90a192b09

#sudo ip netns exec $QR ip route add 10.10.20.0/24 via $MYIP

sudo ip link set o1 netns $QR
sudo ip netns exec $QR ifconfig o1 10.0.0.20/24 up

sudo ip netns exec $QR ip route add 10.2.0.0/16 via 10.0.0.2
sudo ip netns exec $QR ip route add 10.4.0.0/16 via 10.0.0.4
sudo ip netns exec $QR ip route add 10.5.0.0/16 via 10.0.0.5
sudo ip netns exec $QR ip route add 10.6.0.0/16 via 10.0.0.6
sudo ip netns exec $QR ip route add 10.7.0.0/16 via 10.0.0.7
sudo ip netns exec $QR ip route add 10.8.0.0/16 via 10.0.0.8
sudo ip netns exec $QR ip route add 10.9.0.0/16 via 10.0.0.9
sudo ip netns exec $QR ip route add 10.12.0.0/16 via 10.0.0.12
sudo ip netns exec $QR ip route add 10.22.0.0/16 via 10.0.0.22
sudo ip netns exec $QR ip route add 10.23.0.0/16 via 10.0.0.23
sudo ip netns exec $QR ip route add 10.253.0.0/16 via 10.0.0.253
sudo ip netns exec $QR ip route add 10.254.0.0/16 via 10.0.0.254

