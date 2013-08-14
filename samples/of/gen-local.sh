#!/bin/bash

# gen-local.sh generates localrc for devstack. It's an interactive script, and
# supports the following options:
#   -a) Creates loclrc for compute nodes.

ENABLED_SERVICES_CONTROL="key,n-api,n-crt,n-cpu,n-vol,n-sch,n-novnc,n-xvnc,n-cauth,mysql,rabbit,quantum,q-svc,q-agt,q-l3,q-dhcp"
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
    echo "Run this script from devstack's root: sample/of/gen-local.sh"
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

if [[ -f localrc ]]; then
  echo "localrc already exists. Overwrite? ([y]/n)"
  read OVERWRITE_LOCALRC
  if [[ "$OVERWRITE_LOCALRC" == "n" || "$OVERWRITE_LOCALRC" == "N" ]]; then
    exit 1
  fi
fi

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


#IS_KEYSTONE_CENTRAL=false
KEYSTONE_TYPE="LOCAL"
REGION_NAME="CORE"
KEYSTONE_AUTH_HOST=""

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

if [[ $AGENT == 0 ]]; then
  echo "Which interface should be used to connect virtual instances to the external network? (ie, "$(interfaces)")?"
  read EXT_NET_INT

  if ! interface_exists $EXT_NET_INT; then
    echo "There is no interface "$EXT_NET_INT
    exit 1
  fi
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

if [[ $AGENT == 0 ]]; then
  FLOATING_RANGE=10.10.10.100
  echo "What is the floating range? [$FLOATING_RANGE]"
  read FLOATING_RANGE_READ
  if [ $FLOATING_RANGE_READ ]; then
    FLOATING_RANGE=$FLOATING_RANGE_READ
  fi


  while true; do
    read -p "Do you want to install Keystone?" yn
    case $yn in
        [Nn]* ) read -p "Please Enter Central Keystone IP address?" KEYSTONE_AUTH_HOST; read -p "Please Enter Region name?" REGION_NAME;KEYSTONE_TYPE="CENTRAL";break;;
        [Yy]* ) KEYSTONE_AUTH_HOST=$HOST_IP;break;;
        * ) echo "Please answer yes or no.";;
    esac
  done
  REGIONS=""
  if [[ "$KEYSTONE_TYPE" = "LOCAL" ]]; then
   read -p "Please Enter the region of this node[$REGION_NAME]:" reg
   if [[ -z "${reg}" ]]; then
      echo "The current region is $REGION_NAME"
   else
      REGION_NAME=$reg
   fi
   ENABLED_SERVICES_CONTROL+=",horizon"
   read -p "Please Enter the rest of regions in comma separated format: " regs
   REGIONS=$REGION_NAME","$regs
  fi
  echo ""

  SWIFT_DISK_SIZE=5000000
  echo "What is the loopback disk size for Swift? [$SWIFT_DISK_SIZE]"
  read SWIFT_DISK_SIZE_READ
  if [ $SWIFT_DISK_SIZE_READ ]; then
    SWIFT_DISK_SIZE=$SWIFT_DISK_SIZE_READ
  fi

  echo ""

  #GLANCE CONFIG
  echo "Do you want to running both glance registry and glance api in the same machine?([y]/n)"
  read RUN_BOTH_GLANCE_REG_API
  if [[ "$RUN_BOTH_GLANCE_REG_API" == "n" ]]; then
    echo "Which glance service do you want to run ([api]/registry)"
    read GLANCE_SERVICE
    if [[ "$GLANCE_SERVICE" == "registry" ]]; then
      GLANCE_REGISTRY_ENABLED=true
      GLANCE_API_ENABLED=false
    else
      GLANCE_API_ENABLED=true
      GLANCE_REGISTRY_ENABLED=false
    fi
  else
    GLANCE_REGISTRY_ENABLED=true
    GLANCE_API_ENABLED=true
  fi

  if [[ "$GLANCE_REGISTRY_ENABLED" == "true" ]]; then
    GLANCE_REGISTRY_AUTH_HOST=$KEYSTONE_AUTH_HOST
    GLANCE_REGISTRY_AUTH_PORT=35357
  fi

  DEF_IMAGE=n

  if [[ "$GLANCE_API_ENABLED" == "true" ]]; then
    GLANCE_REGISTRY_HOST=$HOST_IP
    GLANCE_REGISTRY_PORT=9191

    #registry address for api
    if [[ "$GLANCE_REGISTRY_ENABLED" == "false" ]]; then
      echo "config glance API"

      GLANCE_REGISTRY_HOST=$KEYSTONE_AUTH_HOST
      echo "Enter the host address of the Glance registry server for this glance API [$KEYSTONE_AUTH_HOST]"
      read GLANCE_REGISTRY_HOST_READ

      if [ $GLANCE_REGISTRY_HOST_READ ]; then
        GLANCE_REGISTRY_HOST=$GLANCE_REGISTRY_HOST_READ
      fi

      GLANCE_REGISTRY_PORT=9191

      echo "Enter the port of the Glance registry [9191]"
      read GLANCE_REGISTRY_PORT_READ

      if [ $GLANCE_REGISTRY_PORT_READ ]; then
        GLANCE_REGISTRY_PORT=$GLANCE_REGISTRY_PORT_READ
      fi
  fi

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

  GLANCE_CACHE_MAX_SIZE=2000000000
  echo "Enter the max cache size for this glance API in Bytes [2000000000]"
  read GLANCE_CACHE_MAX_READ

  if [ $GLANCE_CACHE_MAX_READ ]; then
    GLANCE_CACHE_MAX_SIZE=$GLANCE_CACHE_MAX_READ
  fi

  #keystone for Glance API
  GLANCE_API_AUTH_HOST=$KEYSTONE_AUTH_HOST
  GLANCE_API_AUTH_PORT=35357

  #Load default Images to local API
  DEF_IMAGE=y
  while true; do
    read -p "Do you want to load default images?([y]/n)" yn
    case $yn in
        [Nn]* ) DEF_IMAGE=n;break;;
        [Yy]* ) DEF_IMAGE=y;break;;
        * ) break;;
    esac
  done

  echo ""

  fi
fi

read -p "Would you like to use OpenFlow? ([n]/y) " USE_OF

Q_PLUGIN=openvswitch
if [[ "$USE_OF" == "y" || "$USE_OF" == "Y" ]]; then
    echo "This version supports only Ryu."
    echo ''
    Q_PLUGIN=ryu

    read -p "What port is the OpenFlow controller listening on? [6634] " OF_PORT
    if [ ! $OF_PORT ]; then
        OF_PORT=6634
    fi
    echo ''

    read -p "Do you want to install FlowVisor? ([n]/y) " FV_ENABLED
    if [[ "$FV_ENABLED" == "y" || "$FV_ENABLED" == "Y" ]]; then
        read -p "What port is FlowVisor listening on? [6633] " FV_PORT
        if [ ! $FV_PORT ]; then
            FV_PORT=6633
        fi

        while [[ "$OF_PORT" == "$FV_PORT" ]]; do
            read -p "FlowVisor port conflict with OpenFlow controller port. Choose another. " FV_PORT
        done
    fi
    echo ''

    if [[ $AGENT == 0 ]]; then
        read -p "Do you want to use SDI Manager? ([y]/n) " SDI_ENABLED
    else
        read -p "Is the SDI Manager in use on the controller node? ([y]/n)" SDI_ENABLED
    fi

    if [[ "$SDI_ENABLED" == "n" || "$SDI_ENABLED" == "N" ]]; then
        USE_SDI=false
    else
        USE_SDI=true
        Q_PLUGIN=janus
    fi
    echo ''
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
  if [[ $USE_OF == "y" || "$USE_OF" == "Y" ]]; then
    sed -i -e 's/RYU_ENABLED_//g' localrc
  else
    sed -i -e 's/RYU_ENABLED_/#/g' localrc
  fi
  
  if [[ "$FV_ENABLED" == "y" || "$FV_ENABLED" == "Y" ]]; then
    sed -i -e 's/FV_ENABLED_//g' localrc
    
    # Change Ryu OFP port so it doesn't conflict with FV's OFP port
    sed -i -e 's/6633/6634/g' localrc

    echo "Note: If you want to use the 'fvctl' CLI tool native to FlowVisor, it is recommended you add an alias to .bashrc:"
    echo "    alias fvctl='fvctl -f /etc/flowvisor/passFile -h 127.0.0.1 -p 8085'"
  else
    sed -i -e 's/FV_ENABLED_/#/g' localrc
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

  if [[ $USE_SDI == "true" ]]; then
    sed -i -e 's/SDI_ENABLED_//g' localrc
  else
    sed -i -e 's/SDI_ENABLED_/#/g' localrc
  fi

  sed -i -e 's/\${ENABLED_SERVICES}/'$ENABLED_SERVICES_CONTROL'/g' localrc
  sed -i -e 's/\${HOST_IP_IFACE}/'$HOST_INT'/g' localrc
  sed -i -e 's/\${FLAT_INTERFACE}/'$FLAT_INT'/g' localrc
  sed -i -e 's/\${EXT_NET_IFACE}/'$EXT_NET_INT'/g' localrc
  sed -i -e 's/\${PUBLIC_INTERFACE}/'$PUBLIC_INT'/g' localrc
  sed -i -e 's/\${HOST_IP}/'$HOST_IP'/g' localrc
  sed -i -e 's/\${PUBLIC_SERVICE_HOST}/'$PUBLIC_IP'/g' localrc
  sed -i -e 's/\${FLOATING_RANGE}/'$FLOATING_RANGE'/g' localrc
  sed -i -e 's/\${PASSWORD}/'$PASSWORD'/g' localrc
  sed -i -e 's/\${Q_PLUGIN}/'$Q_PLUGIN'/g' localrc
  sed -i -e 's/\${RYU_HOST}/'$HOST_IP'/g' localrc
  sed -i -e 's/\${RYU_PORT}/'$OF_PORT'/g' localrc
  sed -i -e 's/\${FV_PORT}/'$FV_PORT'/g' localrc
  sed -i -e 's/\${SWIFT_DISK_SIZE}/'$SWIFT_DISK_SIZE'/g' localrc
  sed -i -e 's/\${REGIONS}/'$REGIONS'/g' localrc
  if [ $DEF_IMAGE == "n" ]; then
    echo "IMAGE_URLS=" >> localrc
  fi

  if [[ -f local.sh ]]; then
    read -p "local.sh already exists. Overwrite? ([y]/n) " OVERWRITE_LOCAL_SH
    if [[ "$OVERWRITE_LOCAL_SH" == "n" || "$OVERWRITE_LOCAL_SH" == "N" ]]; then
      echo "localrc generated for the controller node."
      exit 1
    fi
  fi
  cp $OF_DIR/local.sh.template local.sh

  echo "localrc generated for the controller node."
else
  echo "What's the controller's management ip address?"
  read CTRL_IP

  cp $OF_DIR/agent-localrc localrc

  if [[ $USE_OF == "y" ]]; then
    sed -i -e 's/RYU_ENABLED_//g' localrc
  else
    sed -i -e 's/RYU_ENABLED_/#/g' localrc
  fi

  if [[ $USE_SDI == "true" ]]; then
    sed -i -e 's/SDI_ENABLED_//g' localrc
  else
    sed -i -e 's/SDI_ENABLED_/#/g' localrc
  fi

  sed -i -e 's/\${CONTROLLER_HOST}/'$CTRL_IP'/g' localrc
  sed -i -e 's/\${FLAT_INTERFACE}/'$FLAT_INT'/g' localrc
  sed -i -e 's/\${HOST_IP}/'$HOST_IP'/g' localrc
  sed -i -e 's/\${PASSWORD}/'$PASSWORD'/g' localrc
  sed -i -e 's/\${Q_PLUGIN}/'$Q_PLUGIN'/g' localrc
  sed -i -e 's/\${RYU_HOST}/'$CTRL_IP'/g' localrc
  sed -i -e 's/\${RYU_PORT}/'$OF_PORT'/g' localrc
  sed -i -e 's/\${FV_PORT}/'$FV_PORT'/g' localrc

  echo "localrc generated for a compute node."
fi
sed -i -e 's/\${KEYSTONE_TYPE}/'$KEYSTONE_TYPE'/g' localrc
sed -i -e 's/\${REGION_NAME}/'$REGION_NAME'/g' localrc
sed -i -e 's/\${KEYSTONE_AUTH_HOST}/'$KEYSTONE_AUTH_HOST'/g' localrc

echo "Now run ./stack.sh"

