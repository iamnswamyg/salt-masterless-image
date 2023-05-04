
SCRIPT_PREFIX="salt-mless"
OS=images:ubuntu/jammy
OS_FINGERPRINT="39da8bdecb9450521ec97683265fbc51fa1f29c0eabae102e7be78e787788047"
STORAGE_PATH="/data/lxd/"${SCRIPT_PREFIX}
IP="10.120.11"
IFACE="eth0"
IP_SUBNET=${IP}".1/24"
SALT_MASTER_POOL=${SCRIPT_PREFIX}"-pool"
SCRIPT_PROFILE_NAME=${SCRIPT_PREFIX}"-profile"
SCRIPT_BRIDGE_NAME=${SCRIPT_PREFIX}"-br"
SALT_MASTER_NAME=${SCRIPT_PREFIX}"-master"

echo "Deleting Image $OS_FINGERPRINT"
sudo lxc image delete $OS_FINGERPRINT
echo "Deleting Profie $SCRIPT_PROFILE_NAME"
lxc profile delete $SCRIPT_PROFILE_NAME
echo "Deleting Network $SCRIPT_BRIDGE_NAME"
lxc network delete $SCRIPT_BRIDGE_NAME
echo "Deleting Pool $SALT_MASTER_POOL"
lxc storage delete $SALT_MASTER_POOL