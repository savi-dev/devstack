#!/bin/bash

# Keep track of the devstack directory
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
source $TOP_DIR/functions
source $TOP_DIR/localrc
USER=`whoami`
USER_GROUP=$(id -g)
DEST=/opt/stack
SWIFT_DATA_DIR=${SWIFT_DATA_DIR:-${DEST}/data/swift}
mkdir -p $SWIFT_DATA_DIR
SWIFT_DRIVE=/dev/sda4

    mkdir -p ${SWIFT_DATA_DIR}/drives/sdb1
    if ! egrep -q ${SWIFT_DATA_DIR}/drives/sdb1 /proc/mounts; then
        sudo mount -t xfs -o noatime,nodiratime,nobarrier,logbufs=8  \
            ${SWIFT_DRIVE} ${SWIFT_DATA_DIR}/drives/sdb1
            #${SWIFT_DATA_DIR}/drives/images/swift.img ${SWIFT_DATA_DIR}/drives/sdb1
    fi

    # Create a link to the above mount
    for x in $(seq ${SWIFT_REPLICAS}); do
        sudo ln -sf ${SWIFT_DATA_DIR}/drives/sdb1/$x ${SWIFT_DATA_DIR}/$x; done

    # Create all of the directories needed to emulate a few different servers
    for x in $(seq ${SWIFT_REPLICAS}); do
            drive=${SWIFT_DATA_DIR}/drives/sdb1/${x}
            node=${SWIFT_DATA_DIR}/${x}/node
            node_device=${node}/sdb1
            [[ -d $node ]] && continue
            [[ -d $drive ]] && continue
            sudo install -o ${USER} -g $USER_GROUP -d $drive
            sudo install -o ${USER} -g $USER_GROUP -d $node_device
            sudo chown -R $USER: ${node}
    done

#sudo swift-init start all
