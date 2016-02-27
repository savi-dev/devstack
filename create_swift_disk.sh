#!/bin/bash

XTRACE=$(set +o | grep xtrace)
set +o xtrace

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


# Set ``SWIFT_DATA_DIR`` to the location of swift drives and objects.
# Default is the common DevStack data directory.
SWIFT_DISK_IMAGE=${SWIFT_DATA_DIR}/drives/images/swift.img


    sudo mkdir -p ${SWIFT_DATA_DIR}/{drives,cache,run,logs}
    sudo chown -R $USER:${USER_GROUP} ${SWIFT_DATA_DIR}

    # Create a loopback disk and format it to XFS.
    if [[ -e ${SWIFT_DISK_IMAGE} ]]; then
        if egrep -q ${SWIFT_DATA_DIR}/drives/sdb1 /proc/mounts; then
            sudo umount ${SWIFT_DATA_DIR}/drives/sdb1
            sudo rm -f ${SWIFT_DISK_IMAGE}
        fi
    fi

    mkdir -p ${SWIFT_DATA_DIR}/drives/images
    sudo touch ${SWIFT_DISK_IMAGE}
    sudo chown $USER: ${SWIFT_DISK_IMAGE}

    truncate -s ${SWIFT_LOOPBACK_DISK_SIZE} ${SWIFT_DISK_IMAGE}

    # Make a fresh XFS filesystem
    mkfs.xfs -f -i size=1024  ${SWIFT_DISK_IMAGE}


