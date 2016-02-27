
#!/bin/bash
set -x
source localrc
source functions

source openrc

source lib/neutron

DNS_NAMESERVER=`sudo cat /etc/resolv.conf | grep name | awk '{print $2}' | head`

export DNS_NAMESERVER

create_neutron_initial_network

sleep 5

ports=`sudo ovs-ofctl show br-int | grep tap | sed "s/[(^)]/ /g" | awk '{print $2}'`
for port in $ports; do echo $port; ofp=`sudo ovs-vsctl get interface $port ofport`; sudo ovs-vsctl set interface $port external_ids:ofport=$ofp; done
ports=`sudo ovs-ofctl show br-int | grep qr | sed "s/[(^)]/ /g" | awk '{print $2}'`
for port in $ports; do echo $port; ofp=`sudo ovs-vsctl get interface $port ofport`; sudo ovs-vsctl set interface $port external_ids:ofport=$ofp; done


