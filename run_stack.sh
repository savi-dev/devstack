#!/bin/bash

# Keep track of the devstack directory
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
source $TOP_DIR/functions
source $TOP_DIR/stackrc
source $TOP_DIR/localrc
source $TOP_DIR/lib/nova
source $TOP_DIR/lib/glance
source $TOP_DIR/lib/cinder
source $TOP_DIR/lib/quantum
source $TOP_DIR/lib/whale

HORIZON_DIR=$DEST/horizon
OPENSTACKCLIENT_DIR=$DEST/python-openstackclient
NOVNC_DIR=$DEST/noVNC
SWIFT_DIR=$DEST/swift
SWIFT3_DIR=$DEST/swift3
SWIFTCLIENT_DIR=$DEST/python-swiftclient
QUANTUM_DIR=$DEST/quantum
QUANTUM_CLIENT_DIR=$DEST/python-quantumclient
RYU_DIR=$DEST/ryu
JANUS_DIR=$DEST/janus
WHALE_DIR=$DEST/whale

if [[ "$Q_PLUGIN" = "ryu" ]]; then
    AGENT_BINARY="$QUANTUM_DIR/bin/quantum-ryu-agent"
    Q_PLUGIN_CONF_PATH=etc/quantum/plugins/ryu
    Q_PLUGIN_CONF_FILENAME=ryu.ini
elif [[ "$Q_PLUGIN" = "janus" ]]; then
    AGENT_BINARY="$QUANTUM_DIR/quantum/plugins/janus/agent/janus_quantum_agent"
    Q_PLUGIN_CONF_PATH=etc/quantum/plugins/janus
    Q_PLUGIN_CONF_FILENAME=janus.ini
else
    echo "ERROR: Unknown Quantum plugin"
    exit 1
fi
AGENT_DHCP_BINARY="$QUANTUM_DIR/bin/quantum-dhcp-agent"
AGENT_L3_BINARY="$QUANTUM_DIR/bin/quantum-l3-agent"
Q_L3_CONF_FILE=/etc/quantum/l3_agent.ini

Q_CONF_FILE=/etc/quantum/quantum.conf
Q_DHCP_CONF_FILE=/etc/quantum/dhcp_agent.ini

Q_PLUGIN_CONF_FILE=$Q_PLUGIN_CONF_PATH/$Q_PLUGIN_CONF_FILENAME

# FlowVisor Config File for Default Ryu Control
RYU_FV_CONFIG=${RYU_FV_CONFIG:-/etc/flowvisor/fv_config.json}

RYU_CONF_DIR=/etc/ryu
RYU_CONF=$RYU_CONF_DIR/ryu.conf

MANAGEMENT_IP_IFACE=${MANAGEMENT_IP_IFACE:-p3}
MANAGEMENT_IP_RANGE=${MANAGEMENT_IP_RANGE:-10.10.20.2/24}

BM_CONF=/etc/nova-bm
BEE2_CONF=/etc/nova-bee2

BM_PXE_INTERFACE=${BM_PXE_INTERFACE:-eth1}
BM_PXE_PER_NODE=`trueorfalse False $BM_PXE_PER_NODE`
TFTPROOT=$DEST/tftproot

DNSMASQ_PID=/dnsmasq.pid
if [ -f "$DNSMASQ_PID" ]; then
    sudo kill `cat "$DNSMASQ_PID"`
    sudo rm "$DNSMASQ_PID"
fi

NL=`echo -ne '\015'`

SCREEN_NAME=${SCREEN_NAME:-stack}
# Check to see if we are already running DevStack
if type -p screen >/dev/null && screen -ls | egrep -q "[0-9].$SCREEN_NAME"; then
    echo "You are already running a stack.sh session."
    echo "To rejoin this session type 'screen -x stack'."
    echo "To destroy this session, type './unstack.sh'."
    exit 1
fi

if [ -z "$SCREEN_HARDSTATUS" ]; then
    SCREEN_HARDSTATUS='%{= .} %-Lw%{= .}%> %n%f %t*%{= .}%+Lw%< %-=%{g}(%{d}%H/%l%{g})'
fi

# Create a new named screen to run processes in
screen -d -m -S $SCREEN_NAME -t shell -s /bin/bash
sleep 1
# Set a reasonable status bar
screen -r $SCREEN_NAME -X hardstatus alwayslastline "$SCREEN_HARDSTATUS"

echo test  n-cpu "cd $NOVA_DIR && sg libvirtd $NOVA_BIN_DIR/nova-compute"
echo test  n-crt "cd $NOVA_DIR && $NOVA_BIN_DIR/nova-cert"
echo test  n-net "cd $NOVA_DIR && $NOVA_BIN_DIR/nova-network"
echo test  n-sch "cd $NOVA_DIR && $NOVA_BIN_DIR/nova-scheduler --config-dir=$BM_CONF $NL"
echo test  n-novnc "cd $NOVNC_DIR && ./utils/nova-novncproxy --config-file $NOVA_CONF --web ."
echo test  n-xvnc "cd $NOVA_DIR && ./bin/nova-xvpvncproxy --config-file $NOVA_CONF"
echo test  n-cauth "cd $NOVA_DIR && ./bin/nova-consoleauth"
echo test  g-api "cd $GLANCE_DIR; $GLANCE_BIN_DIR/glance-api --config-file=$GLANCE_CONF_DIR/glance-api.conf"
echo test  c-api "cd $CINDER_DIR && $CINDER_BIN_DIR/cinder-api --config-file $CINDER_CONF"
echo test  c-vol "cd $CINDER_DIR && $CINDER_BIN_DIR/cinder-volume --config-file $CINDER_CONF"
echo test  c-sch "cd $CINDER_DIR && $CINDER_BIN_DIR/cinder-scheduler --config-file $CINDER_CONF"
echo test  n-vol "cd $NOVA_DIR && $NOVA_BIN_DIR/nova-volume"
echo test neo4j "cd $GRAPH_DB_DIR && $GRAPH_DB_DIR/bin/neo4j console"
echo test w-sync "cd $WHALE_DIR && $WHALE_DIR/bin/whale-init --config-file $WHALE_CONF"
echo test w-api "cd $WHALE_DIR && $WHALE_DIR/bin/whale-server --config-file $WHALE_CONF"
echo test janus "cd $JANUS_DIR && $JANUS_DIR/bin/janus-init"
echo test  ryu "cd $RYU_DIR && $RYU_DIR/bin/ryu-manager --flagfile $RYU_CONF --app_lists ryu.app.ofctl_rest,ryu.app.ryu2janus,ryu.app.discovery,ryu.app.rest_discovery"
echo test  n-api "cd $NOVA_DIR && $NOVA_BIN_DIR/nova-api"
echo test  q-svc "cd $QUANTUM_DIR && python $QUANTUM_DIR/bin/quantum-server --config-file $Q_CONF_FILE --config-file /$Q_PLUGIN_CONF_FILE"
echo test  q-dhcp "python $AGENT_DHCP_BINARY --config-file $Q_CONF_FILE --config-file=$Q_DHCP_CONF_FILE"
echo test  q-l3 "python $AGENT_L3_BINARY --config-file $Q_CONF_FILE --config-file=$Q_L3_CONF_FILE"
echo test  q-agt "python $AGENT_BINARY --config-file $Q_CONF_FILE --config-file /$Q_PLUGIN_CONF_FILE"
echo test  fv "cd ~ && sudo -u flowvisor flowvisor -l $RYU_FV_CONFIG"
echo test  fv-agt "cd $JANUS_DIR/janus/network/agent/flowvisor && ./janus_flowvisor_agent"

echo test n-bmd "cd $NOVA_DIR && $NOVA_BIN_DIR/bm_deploy_server --config-dir=$BM_CONF $NL"
echo test n-cpu-bm "cd $NOVA_DIR && sg libvirtd \"$NOVA_BIN_DIR/nova-compute --config-dir=$BM_CONF\" $NL"
echo test n-cpu-bee2 "cd $NOVA_DIR && sg libvirtd \"$NOVA_BIN_DIR/nova-compute --config-dir=$BEE2_CONF\" $NL"

screen_it neo4j "cd $GRAPH_DB_DIR && $GRAPH_DB_DIR/bin/neo4j console"
sleep 10
screen_it w-sync "cd $WHALE_DIR && $WHALE_DIR/bin/whale-init --config-file /etc/whale/whale.conf"
sleep 10
screen_it w-api "cd $WHALE_DIR && $WHALE_DIR/bin/whale-server --config-file /etc/whale/whale.conf"
sleep 5
screen_it janus "cd $JANUS_DIR && $JANUS_DIR/bin/janus-init --config-file /etc/janus/janus.conf"
sleep 5
screen_it  ryu "cd $RYU_DIR && $RYU_DIR/bin/ryu-manager --flagfile $RYU_CONF --app_lists ryu.app.ofctl_rest,ryu.app.ryu2janus,ryu.app.discovery,ryu.app.rest_discovery"
sleep 5
screen_it  n-api "cd $NOVA_DIR && $NOVA_BIN_DIR/nova-api"
screen_it  g-api "cd $GLANCE_DIR; $GLANCE_BIN_DIR/glance-api --config-file=$GLANCE_CONF_DIR/glance-api.conf"
screen_it  q-svc "cd $QUANTUM_DIR && python $QUANTUM_DIR/bin/quantum-server --config-file $Q_CONF_FILE --config-file /$Q_PLUGIN_CONF_FILE"
sleep 10
screen_it  q-dhcp "python $AGENT_DHCP_BINARY --config-file $Q_CONF_FILE --config-file=$Q_DHCP_CONF_FILE"
sleep 5
screen_it  q-l3 "python $AGENT_L3_BINARY --config-file $Q_CONF_FILE --config-file=$Q_L3_CONF_FILE"
sleep 5
screen_it  q-agt "python $AGENT_BINARY --config-file $Q_CONF_FILE --config-file /$Q_PLUGIN_CONF_FILE"
sleep 5
#screen_it  n-cpu "cd $NOVA_DIR && sg libvirtd $NOVA_BIN_DIR/nova-compute"
screen_it  n-crt "cd $NOVA_DIR && $NOVA_BIN_DIR/nova-cert"
#screen_it  n-net "cd $NOVA_DIR && $NOVA_BIN_DIR/nova-network"
screen_it  n-sch "cd $NOVA_DIR && $NOVA_BIN_DIR/nova-scheduler --config-dir=$BM_CONF $NL"
screen_it  n-novnc "cd $NOVNC_DIR && ./utils/nova-novncproxy --config-file $NOVA_CONF --web ."
screen_it  n-xvnc "cd $NOVA_DIR && ./bin/nova-xvpvncproxy --config-file $NOVA_CONF"
screen_it  n-cauth "cd $NOVA_DIR && ./bin/nova-consoleauth"
screen_it  c-api "cd $CINDER_DIR && $CINDER_BIN_DIR/cinder-api --config-file $CINDER_CONF"
screen_it  c-vol "cd $CINDER_DIR && $CINDER_BIN_DIR/cinder-volume --config-file $CINDER_CONF"
screen_it  c-sch "cd $CINDER_DIR && $CINDER_BIN_DIR/cinder-scheduler --config-file $CINDER_CONF"
#screen_it  n-vol "cd $NOVA_DIR && $NOVA_BIN_DIR/nova-volume"
screen_it  fv "cd ~ && sudo -u flowvisor flowvisor -l $RYU_FV_CONFIG"
if is_service_enabled fv-agt; then
    sleep 2
    screen_it fv-agt "cd $JANUS_DIR/janus/network/agent/flowvisor && ./janus_flowvisor_agent"
fi

sudo /etc/init.d/dnsmasq stop
sudo sudo update-rc.d dnsmasq disable
if [ "$BM_PXE_PER_NODE" = "False" ]; then
    sudo dnsmasq --conf-file= --port=0 --enable-tftp --tftp-root=$TFTPROOT --dhcp-boot=pxelinux.0 --bind-interfaces --pid-file=$DNSMASQ_PID --interface=$BM_PXE_INTERFACE --dhcp-range=10.61.10.150,10.61.10.254 --dhcp-option=option:dns-server,8.8.8.8
fi

screen_it n-bmd "cd $NOVA_DIR && $NOVA_BIN_DIR/bm_deploy_server --config-dir=$BM_CONF $NL"
screen_it n-cpu-bm "cd $NOVA_DIR && sg libvirtd \"$NOVA_BIN_DIR/nova-compute --config-dir=$BM_CONF\" $NL"
#screen_it n-cpu-bee2 "cd $NOVA_DIR && sg libvirtd \"$NOVA_BIN_DIR/nova-compute --config-dir=$BEE2_CONF\" $NL"

#this scripts assumes bridges and interfaces are setup corretcky

echo "done baremetal local.sh"

#. $TOP_DIR/port_reg.sh
#. $TOP_DIR/port_bond.sh
#$TOP_DIR/tenant-add.sh

QR_NS=`sudo ip netns list | grep qr`

sudo ip link set p3 netns $QR_NS

$TOP_DIR/tests/netns-run.sh $QR_NS "ifconfig p3 10.60.10.2/24 up"

#sudo ovs-vsctl --no-wait -- --may-exist add-port br-ex p4 -- set interface p4 type=internal
#sudo ip link set eth7 netns $QR_NS
#$TOP_DIR/tests/netns-run.sh $QR_NS "ifconfig eth7 10.0.0.2/24 up"
#$TOP_DIR/tests/netns-run.sh $QR_NS "ip route add 10.12.0.0/16 via 10.0.0.12"
#$TOP_DIR/tests/netns-run.sh $QR_NS "ip route add 10.22.0.0/16 via 10.0.0.22"
