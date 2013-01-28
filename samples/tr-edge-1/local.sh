set -x

TOP_DIR=$(cd $(dirname "$0") && pwd)
source $TOP_DIR/stackrc
source $TOP_DIR/functions
DEST=${DEST:-/opt/stack}
IMG_DIR=${IMG_DIR:-/mnt/volume/image_dir}
source $TOP_DIR/openrc admin admin CORE $KEYSTONE_AUTH_HOST

NOVA_DIR=$DEST/nova
if [ -d $NOVA_DIR/bin ] ; then
    NOVA_BIN_DIR=$NOVA_DIR/bin
else
    NOVA_BIN_DIR=/usr/local/bin
fi

MYSQL_USER=${MYSQL_USER:-root}
BM_PXE_INTERFACE=${BM_PXE_INTERFACE:-eth1}
BM_PXE_PER_NODE=`trueorfalse False $BM_PXE_PER_NODE`

$NOVA_BIN_DIR/nova-manage instance_type create --name=baremetal.small --cpu=2 --memory=2048 --root_gb=40 --ephemeral_gb=20 --swap=2048 --rxtx_factor=1 --flavor=6
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=baremetal.small --key cpu_arch --value x86_64
$NOVA_BIN_DIR/nova-manage instance_type create --name=baremetal.medium --cpu=1 --memory=4096 --root_gb=40 --ephemeral_gb=20 --swap=2048 --rxtx_factor=1 --flavor=7
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=baremetal.medium --key cpu_arch --value x86_64
$NOVA_BIN_DIR/nova-manage instance_type create --name=baremetal.minimum --cpu=1 --memory=1 --root_gb=40 --ephemeral_gb=0 --swap=2048 --rxtx_factor=1 --flavor=8
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=baremetal.minimum --key cpu_arch --value x86_64
$NOVA_BIN_DIR/nova-manage instance_type create --name=gpu --cpu=1 --memory=1 --root_gb=100 --ephemeral_gb=0 --swap=2048 --rxtx_factor=1 --flavor=9
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=gpu --key cpu_arch --value gpu_x86_64
$NOVA_BIN_DIR/nova-manage instance_type create --name=netfpga.10g --cpu=1 --memory=1 --root_gb=40 --ephemeral_gb=0 --swap=2048 --rxtx_factor=1 --flavor=10
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=netfpga.10g --key cpu_arch --value nf2_x86_64
$NOVA_BIN_DIR/nova-manage instance_type create --name=netfpga.1g --cpu=1 --memory=1 --root_gb=40 --ephemeral_gb=0 --swap=2048 --rxtx_factor=1 --flavor=11
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=netfpga.1g --key cpu_arch --value nf1_i686
$NOVA_BIN_DIR/nova-manage instance_type create --name=baremetal32.minimum --cpu=1 --memory=1 --root_gb=30 --ephemeral_gb=0 --swap=2048 --rxtx_factor=1 --flavor=12
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=baremetal32.minimum --key cpu_arch --value i686
$NOVA_BIN_DIR/nova-manage instance_type create --name=bee2 --cpu=1 --memory=1 --root_gb=40 --ephemeral_gb=0 --swap=2048 --rxtx_factor=1 --flavor=13
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=bee2 --key cpu_arch --value bee2_board

$NOVA_BIN_DIR/nova-manage instance_type set_key --name=m1.tiny --key cpu_arch --value virtual
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=m1.small --key cpu_arch --value virtual
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=m1.medium --key cpu_arch --value virtual
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=m1.large --key cpu_arch --value virtual
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=m1.xlarge --key cpu_arch --value virtual

sudo apt-get -y install dnsmasq syslinux ipmitool qemu-kvm open-iscsi snmp

sudo apt-get -y install busybox tgt

BMIB_REPO=https://github.com/hesamrahimi/baremetal-initrd-builder.git
BMIB_DIR=$DEST/barematal-initrd-builder
BMIB_BRANCH=silver
git_clone $BMIB_REPO $BMIB_DIR $BMIB_BRANCH

KERNEL=~/deploy_kernel
RAMDISK=~/deploy_ramdisk

if [ ! -f "$RAMDISK" ]; then
(
        KERNEL_VER=`uname -r`
        KERNEL_=/boot/vmlinuz-$KERNEL_VER
        sudo cp "$KERNEL_" "$KERNEL"
        sudo chmod a+r "$KERNEL"
        cd "$BMIB_DIR"
        ./baremetal-mkinitrd.sh "$RAMDISK" "$KERNEL_VER"
)
fi

#GLANCE_HOSTPORT=${GLANCE_HOSTPORT:-$GLANCE_HOST:9292}

#echo "user is: $OS_USERNAME"
#echo "pass is: ...."
#echo "region is: $OS_REGION_NAME"
#echo "tenant is $OS_TENANT_NAME"
#echo "os_auth_url is $OS_AUTH_URL"

#KERNEL_ID=$(glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOSTPORT image-create --name "baremetal-deployment-kernel" --public --container-format aki --disk-format aki < "$KERNEL" | grep ' id ' | get_field 2)

glance image-list | grep baremetal-deployment | awk '{ print $2 }' | xargs glance image-delete  

KERNEL_ID=$(glance image-create --name "baremetal-deployment-kernel" --public --container-format aki --disk-format aki < "$KERNEL" | grep ' id ' | get_field 2)
echo "$KERNEL_ID"

#RAMDISK_ID=$(glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOSTPORT image-create --name "baremetal-deployment-ramdisk" --public --container-format ari --disk-format ari < "$RAMDISK" | grep ' id ' | get_field 2)
RAMDISK_ID=$(glance image-create --name "baremetal-deployment-ramdisk" --public --container-format ari --disk-format ari < "$RAMDISK" | grep ' id ' | get_field 2)
echo "$RAMDISK_ID"

echo "building ubuntu image"
IMG=$IMG_DIR/ubuntu.img

./build-ubuntu-image.sh "$IMG" "$DEST"

ACTIVE_REGION=$OS_REGION_NAME
export OS_REGION_NAME=CORE


IMAGE_ID_OLD=$(glance image-list | grep Ubuntu64)
if [[ $IMAGE_ID_OLD = "" ]]; then 
#REAL_KERNEL_ID=$(glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOSTPORT image-create --name "baremetal-real-kernel" --public --container-format aki --disk-format aki < "$DEST/kernel" | grep ' id ' | get_field 2)
   REAL_KERNEL_ID=$(glance image-create --name "baremetal-64-real-kernel" --public --container-format aki --disk-format aki < "$DEST/kernel" | grep ' id ' | get_field 2)

#REAL_RAMDISK_ID=$(glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOSTPORT image-create --name "baremetal-real-ramdisk" --public --container-format ari --disk-format ari < "$DEST/initrd" | grep ' id ' | get_field 2)
   REAL_RAMDISK_ID=$(glance image-create --name "baremetal-64-real-ramdisk" --public --container-format ari --disk-format ari < "$DEST/initrd" | grep ' id ' | get_field 2)

#glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOSTPORT image-create --name "Ubuntu" --public --container-format bare --disk-format raw --property kernel_id=$REAL_KERNEL_ID --property ramdisk_id=$REAL_RAMDISK_ID < "$IMG"
   glance image-create --name "Ubuntu64" --public --container-format bare --disk-format raw --property kernel_id=$REAL_KERNEL_ID --property ramdisk_id=$REAL_RAMDISK_ID < "$IMG"
fi

IMG=$IMG_DIR/UbuntuNF2.img
IMAGE_ID_OLD=$(glance image-list | grep UbuntuNF2)
if [[ $IMAGE_ID_OLD = "" && -f "$IMG" ]]; then
   REAL_KERNEL_ID=$(glance image-list | grep "baremetal-64-real-kernel" | awk '{ print $2 }')
   REAL_RAMDISK_ID=$(glance image-list | grep "baremetal-64-real-ramdisk" | awk '{ print $2 }')
   echo "uploading NF2 image"
   glance image-create --name "UbuntuNF2" --public --container-format bare --disk-format raw --property kernel_id=$REAL_KERNEL_ID --property ramdisk_id=$REAL_RAMDISK_ID < "$IMG"
fi

IMG=$IMG_DIR/cuda_ubuntu_12_04.img
IMAGE_ID_OLD=$(glance image-list | grep UbuntuGPU)
if [[ $IMAGE_ID_OLD = "" && -f "$IMG" ]]; then
   REAL_KERNEL_ID=$(glance image-list | grep "baremetal-64-real-kernel" | awk '{ print $2 }')
   REAL_RAMDISK_ID=$(glance image-list | grep "baremetal-64-real-ramdisk" | awk '{ print $2 }')
   echo "Uploading GPU image"
   glance image-create --name "UbuntuGPU" --public --container-format bare --disk-format raw --property kernel_id=$REAL_KERNEL_ID --property ramdisk_id=$REAL_RAMDISK_ID < "$IMG"
fi

KERNEL_32=~/kernel32
RAMDISK_32=~/ramdisk32
IMG_32=$IMG_DIR/ubuntu32.img

IMAGE_ID_OLD=$(glance image-list | grep Ubuntu32)
if [[ $IMAGE_ID_OLD = "" ]]; then 
#REAL_KERNEL_ID=$(glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOSTPORT image-create --name "baremetal-32-real-kernel" --public --container-format aki --disk-format aki < "$KERNEL_32" | grep ' id ' | get_field 2)
   REAL_KERNEL_ID=$(glance image-create --name "baremetal-32-real-kernel" --public --container-format aki --disk-format aki < "$KERNEL_32" | grep ' id ' | get_field 2)

#REAL_RAMDISK_ID=$(glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOSTPORT image-create --name "baremetal-32-real-ramdisk" --public --container-format ari --disk-format ari < "$RAMDISK_32" | grep ' id ' | get_field 2)
   REAL_RAMDISK_ID=$(glance image-create --name "baremetal-32-real-ramdisk" --public --container-format ari --disk-format ari < "$RAMDISK_32" | grep ' id ' | get_field 2)

#glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOSTPORT image-create --name "Ubuntu32" --public --container-format bare --disk-format raw --property kernel_id=$REAL_KERNEL_ID --property ramdisk_id=$REAL_RAMDISK_ID < "$IMG_32"
   glance image-create --name "Ubuntu32" --public --container-format bare --disk-format raw --property kernel_id=$REAL_KERNEL_ID --property ramdisk_id=$REAL_RAMDISK_ID < "$IMG_32"
fi


export OS_REGION_NAME=$ACTIVE_REGION

TFTPROOT=$DEST/tftproot

if [ -d "$TFTPROOT" ]; then
    rm -r "$TFTPROOT"
fi
mkdir "$TFTPROOT"
cp /usr/lib/syslinux/pxelinux.0 "$TFTPROOT"
mkdir $TFTPROOT/pxelinux.cfg

DNSMASQ_PID=/dnsmasq.pid
if [ -f "$DNSMASQ_PID" ]; then
    sudo kill `cat "$DNSMASQ_PID"`
    sudo rm "$DNSMASQ_PID"
fi
sudo /etc/init.d/dnsmasq stop
sudo sudo update-rc.d dnsmasq disable
if [ "$BM_PXE_PER_NODE" = "False" ]; then
    sudo dnsmasq --conf-file= --port=0 --enable-tftp --tftp-root=$TFTPROOT --dhcp-boot=pxelinux.0 --bind-interfaces --pid-file=$DNSMASQ_PID --interface=$BM_PXE_INTERFACE --dhcp-range=10.10.41.150,10.10.41.254 --dhcp-option=option:dns-server,8.8.8.8
fi

mkdir -p $NOVA_DIR/baremetal/console
mkdir -p $NOVA_DIR/baremetal/dnsmasq

OWNER=`whoami`
BM_CONF=/etc/nova-bm

if [ -d "$BM_CONF" ]; then
 echo "nova-bm conf dir exist"
 sudo rm "$BM_CONF" -rf
fi

sudo mkdir $BM_CONF
sudo chown $OWNER:root $BM_CONF -R

sudo cp -p /etc/nova/* $BM_CONF -rf

inicomment $BM_CONF/nova.conf DEFAULT firewall_driver

OWNER=`whoami`
BEE2_CONF=/etc/nova-bee2

if [ -d "$BEE2_CONF" ]; then
 echo "nova-bee2 conf dir exist"
 sudo rm "$BEE2_CONF" -rf
fi

sudo mkdir $BEE2_CONF
sudo chown $OWNER:root $BEE2_CONF -R

sudo cp -p /etc/nova/* $BEE2_CONF -rf

inicomment $BEE2_CONF/nova.conf DEFAULT firewall_driver

function iso() {
    iniset /etc/nova/nova.conf DEFAULT "$1" "$2"
}

function is() {
    iniset $BM_CONF/nova.conf DEFAULT "$1" "$2"
}

function isb() {
    iniset $BEE2_CONF/nova.conf DEFAULT "$1" "$2"
}

BMC_HOST=`hostname -f`
BMC_HOST=bmc-$BMC_HOST

BEE2_HOST=`hostname -f`
BEE2_HOST=bee2-$BEE2_HOST

is baremetal_sql_connection mysql://$MYSQL_USER:$MYSQL_PASSWORD@127.0.0.1/nova_bm
isb baremetal_sql_connection mysql://$MYSQL_USER:$MYSQL_PASSWORD@127.0.0.1/nova_bm
is compute_driver nova.virt.baremetal.driver.BareMetalDriver
isb compute_driver nova.virt.baremetal.driver.BareMetalDriver
is baremetal_driver nova.virt.baremetal.pxe.PXE
isb baremetal_driver nova.virt.bee2.bee2-board.BEE2
isb power_manager nova.virt.bee2.ipmi-fake.Ipmi
#is power_manager nova.virt.baremetal.ipmi-fake.Ipmi
#comment the above line and uncomment the next line if you want to use netbooter
is power_manager nova.virt.baremetal.snmp.SnmpNetBoot
is instance_type_extra_specs cpu_arch:nf_x86_64
isb instance_type_extra_specs cpu_arch:bee2_board
is baremetal_tftp_root $TFTPROOT
#is baremetal_term /usr/local/bin/shellinaboxd
is baremetal_deploy_kernel $KERNEL_ID
is baremetal_deploy_ramdisk $RAMDISK_ID
is scheduler_host_manager nova.scheduler.baremetal_host_manager.BaremetalHostManager
iso scheduler_host_manager nova.scheduler.baremetal_host_manager.BaremetalHostManager
is baremetal_pxe_vlan_per_host $BM_PXE_PER_NODE
is baremetal_pxe_parent_interface $BM_PXE_INTERFACE
is firewall_driver ""
is baremetal_vif_driver nova.virt.baremetal.ryu.ryu_vif_driver.RyuVIFDriver
is host $BMC_HOST
isb host $BEE2_HOST
iso host `hostname -f`

mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e 'DROP DATABASE IF EXISTS nova_bm;'
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e 'CREATE DATABASE nova_bm CHARACTER SET latin1;'

# workaround for invalid compute_node that non-bare-metal nova-compute has left
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD nova -e 'DELETE FROM compute_nodes;'

$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BM_CONF db sync
$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BM_CONF pxe_ip create --cidr 10.10.41.0/24

if [ -f $TOP_DIR/bm-nodes.sh ]; then
    . $TOP_DIR/bm-nodes.sh
fi

if [ -f ./bee2-nodes.sh ]; then
    . ./bee2-nodes.sh
fi

NL=`echo -ne '\015'`

echo "restarting nova-scheduler"
screen -S stack -p n-sch -X kill
screen -S stack -X screen -t n-sch
sleep 1.5
screen -S stack -p n-sch -X stuff "cd $NOVA_DIR && $NOVA_BIN_DIR/nova-scheduler --config-dir=$BM_CONF $NL"
sleep 5

echo "restarting nova-compute"
screen -S stack -p n-cpu -X kill
screen -S stack -X screen -t n-cpu
sleep 1.5
screen -S stack -p n-cpu -X stuff "cd $NOVA_DIR && sg libvirtd \"$NOVA_BIN_DIR/nova-compute --config-dir=/etc/nova\" $NL"

echo "starting bm_deploy_server"
screen -S stack -p n-bmd -X kill
screen -S stack -X screen -t n-bmd
sleep 1.5
screen -S stack -p n-bmd -X stuff "cd $NOVA_DIR && $NOVA_BIN_DIR/bm_deploy_server --config-dir=$BM_CONF $NL"

echo "starting baremetal nova-compute"
screen -S stack -p n-cpu-bm -X kill
screen -S stack -X screen -t n-cpu-bm
sleep 1.5
screen -S stack -p n-cpu-bm -X stuff "cd $NOVA_DIR && sg libvirtd \"$NOVA_BIN_DIR/nova-compute --config-dir=$BM_CONF\" $NL"

echo "starting bee2Board nova-compute"
screen -S stack -p n-cpu-bee2 -X kill
screen -S stack -X screen -t n-cpu-bee2
sleep 1.5
screen -S stack -p n-cpu-bee2 -X stuff "cd $NOVA_DIR && sg libvirtd \"$NOVA_BIN_DIR/nova-compute --config-dir=$BEE2_CONF\" $NL"

if [[ $PUBLIC_INTERFACE != "" ]]; then
  TEMP_BR=`sudo ovs-vsctl port-to-br $PUBLIC_INTERFACE`
  if [[ $TEMP_BR != $PUBLIC_BRIDGE ]]; then
     echo "removing $PUBLIC_INTERFACE from $TEMP_BR"
     sudo ovs-vsctl del-port $TEMP_BR $PUBLIC_INTERFACE
     TEMP_BR=""
  fi
  if [[ $TEMP_BR = "" ]]; then
     echo "adding $PUBLIC_INTERFACE to $PUBLIC_BRIDGE"
     sudo ovs-vsctl --no-wait -- --may-exist add-port $PUBLIC_BRIDGE $PUBLIC_INTERFACE
  fi
  sudo ifconfig $PUBLIC_INTERFACE up promisc
fi

echo "done baremetal local.sh"

. $TOP_DIR/port_reg.sh
. $TOP_DIR/port_bond.sh

    SERVICE_ENDPOINT=$KEYSTONE_AUTH_PROTOCOL://$KEYSTONE_AUTH_HOST:$KEYSTONE_API_PORT/v2.0 \
    KEYSTONE_AUTH_HOST=$KEYSTONE_AUTH_HOST REGION_NAME=$REGION_NAME \
    HORIZON_DIR=$HORIZON_DIR REGIONS=$REGIONS KEYSTONE_TYPE=$KEYSTONE_TYPE \
    ENABLED_SERVICES=$ENABLED_SERVICES PUBLIC_BRIDGE=$PUBLIC_BRIDGE \
    OS_REGION_NAME=$REGION_NAME ADMIN_PASSWORD=$ADMIN_PASSWORD\
    . $TOP_DIR/local-1.sh

