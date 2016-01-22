#!/bin/bash
. ~/vars.env
REMOTE_USERS=`echo $REMOTE_USERS | sed "s/,/ /g"`
MYIP=`/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`
echo my ip is $MYIP
i=0
for ip in $REMOTE_USERS; do 
    if [ "$ip" == "$MYIP" ]; then    
       continue 
    fi
    if [ "$ip" == "127.0.0.1" ]; then
       continue 
    fi 
    sudo ovs-vsctl add-port br-int gre$i -- set interface gre$i type=gre options:remote_ip=$ip 
    i=$((i + 1))
done
