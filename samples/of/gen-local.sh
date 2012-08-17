#!/bin/bash

# gen-local.sh generates localrc for devstack. It's an interactive script, and
# supports the following options:
#   -a) Creates loclrc for compute nodes.

set -e

function interfaces {
  ip link show | grep -iv LOOPBACK | grep '^[0-9]:\s' | cut -d " " -f 2 |\
    cut -d ":" -f 1
}

function interface_count {
  interfaces | wc -l
}

function ip_address {
  ip addr show $1 | grep "inet\s"  | sed "s/^\s\+//g" | cut -d " " -f 2 |\
    cut -d "/" -f 1
}

function sanity_check {
  if [ ! -f $PWD/stack.sh ]; then
    echo "Run this script from devstack's root: sample/of/local.sh"
    exit 1
  fi

  INTS=$(interface_count)
  if [[ $INTS < 1 ]]; then
    echo "You have less than 2 interfaces. This script needs at least two\
      network interfaces."
    exit 1
  fi
}

function interface_exists {
  ip addr show $1
}

sanity_check

OF_DIR=`dirname $0`

AGENT=0

while getopts ":a" opt; do
  case $opt in
    a)
      echo "Creating localrc for agent."
      AGENT=1
      ;;
  esac
done


echo "Please enter a password (this is going to be used for all services):"
read PASSWORD

echo "Which interface should be used for host (ie, "$(interfaces)")?"
read HOST_INT

if ! interface_exists $HOST_INT; then
  echo "There is no interface "$HOST_INT
  exit 1
fi

echo "Which interface should be used for vm connection (ie, "$(interfaces)")?"
read FLAT_INT

if ! interface_exists $FLAT_INT; then
  echo "There is no interface "$FLAT_INT
  exit 1
fi

HOST_IP=$(ip_address eth0)
echo "What's the ip address of this machine? [$HOST_IP]"
read HOST_IP_READ
if [ $HOST_IP_READ ]; then
  HOST_IP=$HOST_IP_READ
fi

PUBLIC_IP=$HOST_IP
echo "What is the public host address for services endpoints? [$HOST_IP]"
read PUBLIC_IP_READ

if [ $PUBLIC_IP_READ ]; then
  PUBLIC_IP=$PUBLIC_IP_READ
fi

FLOATING_RANGE=10.10.10.100
echo "What is the floating range? [$FLOATING_RANGE]"
read FLOATING_RANGE_READ
if [ $FLOATING_RANGE_READ ]; then
  FLOATING_RANGE=$FLOATING_RANGE_READ
fi

SWIFT_DISK_SIZE=5000000
echo "What is the loopback disk size for Swift? [$SWIFT_DISK_SIZE]"
read SWIFT_DISK_SIZE_READ
if [ $SWIFT_DISK_SIZE_READ ]; then
  SWIFT_DISK_SIZE=$SWIFT_DISK_SIZE_READ
fi

#GLANCE CONFIG
echo "Do you want to running both glance registry and glance api in the same machine?([y]/n)"
read RUN_BOTH_GLANCE_REG_API
if [[ "$RUN_BOTH_GLANCE_REG_API" == "n" ]]; then
  echo "Which glance service do you want to run ([api]/registry)"
  read GLANCE_SERVICE
  if [[ "$GLANCE_SERVICE" == "registry" ]]; then
    GLANCE_REGISTRY_ENABLED=true
  else
    GLANCE_API_ENABLED=true
  fi
else
  GLANCE_REGISTRY_ENABLED=true
  GLANCE_API_ENABLED=true
fi  

if [[ "$GLANCE_REGISTRY_ENABLED" == "true" ]]; then
  echo "config glance registry"
  echo "Enter the keystone host address for glance registry"
  read GLANCE_REGISTRY_AUTH_HOST
  echo "Enter the keystone port for glance registry"
  read GLANCE_REGISTRY_AUTH_PORT
fi

if [[ "$GLANCE_API_ENABLED" == "true" ]]; then
  #registry address for api
  echo "config glance API"
  echo "Enter the host address of the Glance registry server for this glance API"
  read GLANCE_REGISTRY_HOST
  echo "Enter the port of the Glance registry"
  read GLANCE_REGISTRY_PORT

  #cache
  echo "Would you like to enable image cacheing in this API? ([y]/n)"
  read GLANCE_API_USE_CACHE
  if [[ "$GLANCE_API_USE_CACHE" == "n" ]]; then
    GLANCE_API_FLAVOR=keystone
  else
    GLANCE_API_FLAVOR=keystone+cachemanagement
    echo "Enter the time interval (in minutes) between each execution of glance-pruner tool [5]"
    read GLANCE_CACHE_PRUNER_INTERVAL
    if [ -z "$GLANCE_CACHE_PRUNER_INTERVAL" ]; then
      GLANCE_CACHE_PRUNER_INTERVAL=5
    fi
    GLANCE_CACHE_PRUNER_INTERVAL="\/""$GLANCE_CACHE_PRUNER_INTERVAL"
    echo "Enter the time interval (in minutes) between each execution of glance-cleaner tool [10]"
    read GLANCE_CACHE_CLEANER_INTERVAL
    if [ -z "$GLANCE_CACHE_CLEANER_INTERVAL" ]; then
      GLANCE_CACHE_CLEANER_INTERVAL=10
    fi
    GLANCE_CACHE_CLEANER_INTERVAL="\/""$GLANCE_CACHE_CLEANER_INTERVAL"
  fi

  echo "Enter the max cache size for this glance API"
  read GLANCE_CACHE_MAX_SIZE


  #keystone
  echo "Enter the keystone host address for glance api"
  read GLANCE_API_AUTH_HOST
  echo "Enter the keystone port for glance api"
  read GLANCE_API_AUTH_PORT

fi

echo "Would you like to use OpenFlow? ([n]/y)"
read USE_OF

Q_PLUGIN=openvswitch
if [[ "$USE_OF" == "y" ]]; then
  echo "This version supports only Ryu."
  Q_PLUGIN=ryu
fi

if [[ $AGENT == 0 ]]; then

  PUBLIC_INT=$HOST_INT
  echo "Which interface should be used for public connnections [$HOST_INT]?"
  read PUBLIC_INT_READ

  if [ $PUBLIC_INT_READ ]; then 

    if ! interface_exists $PUBLIC_INT_READ; then

      echo "There is no interface "$PUBLIC_INT_READ
      exit 1

    fi

    PUBLIC_INT=$PUBLIC_INT_READ

  fi

  cp $OF_DIR/ctrl-localrc localrc
  if [[ $USE_OF == "y" ]]; then
    sed -i -e 's/RYU_ENABLED_//g' localrc
  else
    sed -i -e 's/RYU_ENABLED_/#/g' localrc
  fi
  
  if [[ $GLANCE_REGISTRY_ENABLED == "true" ]]; then
    sed -i -e 's/GLANCE_REGISTRY_ENABLED_//g' localrc
    if [[ $GLANCE_REGISTRY_AUTH_HOST ]]; then
      sed -i -e 's/\${GLANCE_REGISTRY_AUTH_HOST}/'$GLANCE_REGISTRY_AUTH_HOST'/g' localrc
    else
      sed -i -e 's/GLANCE_REGISTRY_AUTH_HOST=\${GLANCE_REGISTRY_AUTH_HOST}//g' localrc
    fi
    if [[ $GLANCE_REGISTRY_AUTH_PORT ]]; then
      sed -i -e 's/\${GLANCE_REGISTRY_AUTH_PORT}/'$GLANCE_REGISTRY_AUTH_PORT'/g' localrc
    else
      sed -i 's/GLANCE_REGISTRY_AUTH_PORT=\${GLANCE_REGISTRY_AUTH_PORT}//g' localrc
    fi
  else
    sed -i -e 's/GLANCE_REGISTRY_ENABLED_/#/g' localrc
  fi

  if [[ $GLANCE_API_ENABLED == "true" ]]; then
    sed -i -e 's/GLANCE_API_ENABLED_//g' localrc
    sed -i -e 's/\${GLANCE_REGISTRY_HOST}/'$GLANCE_REGISTRY_HOST'/g' localrc
    sed -i -e 's/\${GLANCE_REGISTRY_PORT}/'$GLANCE_REGISTRY_PORT'/g' localrc
    sed -i -e 's/\${GLANCE_CACHE_MAX_SIZE}/'$GLANCE_CACHE_MAX_SIZE'/g' localrc
    sed -i -e 's/\${GLANCE_API_FLAVOR}/'$GLANCE_API_FLAVOR'/g' localrc
    sed -i -e 's/\${GLANCE_CACHE_PRUNER_INTERVAL}/'$GLANCE_CACHE_PRUNER_INTERVAL'/g' localrc
    sed -i -e 's/\${GLANCE_CACHE_CLEANER_INTERVAL}/'$GLANCE_CACHE_CLEANER_INTERVAL'/g' localrc
    if [[ $GLANCE_API_AUTH_HOST ]]; then 
      sed -i -e 's/\${GLANCE_API_AUTH_HOST}/'$GLANCE_API_AUTH_HOST'/g' localrc
    else
      sed -i 's/GLANCE_API_AUTH_HOST=\${GLANCE_API_AUTH_HOST}//g' localrc
    fi
    if [[ $GLANCE_API_AUTH_PORT ]]; then
      sed -i -e 's/\${GLANCE_API_AUTH_PORT}/'$GLANCE_API_AUTH_PORT'/g' localrc
    else
      sed -i 's/GLANCE_API_AUTH_PORT=\${GLANCE_API_AUTH_PORT}//g' localrc
    fi
  else
    sed -i -e 's/GLANCE_API_ENABLED_/*/g' localrc
  fi


  sed -i -e 's/\${HOST_IP_IFACE}/'$HOST_INT'/g' localrc
  sed -i -e 's/\${FLAT_INTERFACE}/'$FLAT_INT'/g' localrc
  sed -i -e 's/\${PUBLIC_INTERFACE}/'$PUBLIC_INT'/g' localrc
  sed -i -e 's/\${HOST_IP}/'$HOST_IP'/g' localrc
  sed -i -e 's/\${PUBLIC_SERVICE_HOST}/'$PUBLIC_IP'/g' localrc
  sed -i -e 's/\${FLOATING_RANGE}/'$FLOATING_RANGE'/g' localrc
  sed -i -e 's/\${PASSWORD}/'$PASSWORD'/g' localrc
  sed -i -e 's/\${Q_PLUGIN}/'$Q_PLUGIN'/g' localrc
  sed -i -e 's/\${RYU_HOST}/'$HOST_IP'/g' localrc
  sed -i -e 's/\${SWIFT_DISK_SIZE}/'$SWIFT_DISK_SIZE'/g' localrc

  echo "localrc generated for the controller node."
else
  echo "What's the controller's ip address?"
  read CTRL_IP

  cp $OF_DIR/agent-localrc localrc

  if [[ $USE_OF == "y" ]]; then
    sed -i -e 's/RYU_ENABLED_//g' localrc
  else
    sed -i -e 's/RYU_ENABLED_/#/g' localrc
  fi

  sed -i -e 's/\${CONTROLLER_HOST}/'$CTRL_IP'/g' localrc
  sed -i -e 's/\${FLAT_INTERFACE}/'$FLAT_INT'/g' localrc
  sed -i -e 's/\${HOST_IP}/'$HOST_IP'/g' localrc
  sed -i -e 's/\${PASSWORD}/'$PASSWORD'/g' localrc
  sed -i -e 's/\${Q_PLUGIN}/'$Q_PLUGIN'/g' localrc
  sed -i -e 's/\${RYU_HOST}/'$CTRL_IP'/g' localrc

  echo "localrc generated for a compute node."
fi

echo "Now run ./stack.sh"
