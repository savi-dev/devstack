HOST=$BEE2_HOST

# Please change parameters according to your bare-metal machine
node_id_bee2_fpga1=$( $NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  node create --host $HOST  --cpus 1 --memory_mb=4096 --local_gb=2 --pm_address="127.0.0.1:6677" --pm_user="null" --pm_password="null" --terminal_port=0 --prov_mac_address=08:00:27:38:98:00 --type=bee2_board)
node_id_bee2_fpga2=$( $NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  node create --host $HOST  --cpus 1 --memory_mb=4096 --local_gb=2 --pm_address="127.0.0.1:6677" --pm_user="null" --pm_password="null" --terminal_port=0 --prov_mac_address=08:00:27:38:98:01 --type=bee2_board)
node_id_bee2_fpga3=$( $NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  node create --host $HOST  --cpus 1 --memory_mb=4096 --local_gb=2 --pm_address="127.0.0.1:6677" --pm_user="null" --pm_password="null" --terminal_port=0 --prov_mac_address=08:00:27:38:98:02 --type=bee2_board)
node_id_bee2_fpga4=$( $NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  node create --host $HOST  --cpus 1 --memory_mb=4096 --local_gb=2 --pm_address="127.0.0.1:6677" --pm_user="null" --pm_password="null" --terminal_port=0 --prov_mac_address=08:00:27:38:98:03 --type=bee2_board)

# Please change parameters according to your bare-metal machine
$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  interface create --node_id=$node_id_bee2_fpga1 --mac_address=08:00:27:C9:00:00 --datapath_id=0x0 --port_no=0
$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  interface create --node_id=$node_id_bee2_fpga1 --mac_address=08:00:27:C9:01:01 --datapath_id=0x0 --port_no=0
$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  interface create --node_id=$node_id_bee2_fpga1 --mac_address=08:00:27:C9:02:02 --datapath_id=0x0 --port_no=0
$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  interface create --node_id=$node_id_bee2_fpga1 --mac_address=08:00:27:C9:03:03 --datapath_id=0x0 --port_no=0

$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  interface create --node_id=$node_id_bee2_fpga2 --mac_address=08:00:27:C9:04:00 --datapath_id=0x0 --port_no=0
$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  interface create --node_id=$node_id_bee2_fpga2 --mac_address=08:00:27:C9:05:01 --datapath_id=0x0 --port_no=0
$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  interface create --node_id=$node_id_bee2_fpga2 --mac_address=08:00:27:C9:06:02 --datapath_id=0x0 --port_no=0
$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  interface create --node_id=$node_id_bee2_fpga2 --mac_address=08:00:27:C9:07:03 --datapath_id=0x0 --port_no=0

$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  interface create --node_id=$node_id_bee2_fpga3 --mac_address=08:00:27:C9:08:00 --datapath_id=0x0 --port_no=0
$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  interface create --node_id=$node_id_bee2_fpga3 --mac_address=08:00:27:C9:09:01 --datapath_id=0x0 --port_no=0
$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  interface create --node_id=$node_id_bee2_fpga3 --mac_address=08:00:27:C9:0a:02 --datapath_id=0x0 --port_no=0
$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  interface create --node_id=$node_id_bee2_fpga3 --mac_address=08:00:27:C9:0b:03 --datapath_id=0x0 --port_no=0

$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  interface create --node_id=$node_id_bee2_fpga4 --mac_address=08:00:27:C9:0c:00 --datapath_id=0x0 --port_no=0
$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  interface create --node_id=$node_id_bee2_fpga4 --mac_address=08:00:27:C9:0d:01 --datapath_id=0x0 --port_no=0
$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  interface create --node_id=$node_id_bee2_fpga4 --mac_address=08:00:27:C9:0e:02 --datapath_id=0x0 --port_no=0
$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BEE2_CONF  interface create --node_id=$node_id_bee2_fpga4 --mac_address=08:00:27:C9:0f:03 --datapath_id=0x0 --port_no=0
