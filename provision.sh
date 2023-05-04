#!/bin/bash

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

IS_MASTER_LOCAL=false


# check if jq exists
if ! snap list | grep jq >>/dev/null 2>&1; then
  sudo snap install jq 
fi
# check if lxd exists
if ! snap list | grep lxd >>/dev/null 2>&1; then
  sudo snap install lxd 
fi

image_names=("${SALT_MASTER_NAME}" )

# Loop through the list of items
for image_name in "${image_names[@]}"
do
    if lxc image list --format=json | jq -r '.[] | .aliases' | jq -r '.[].name' | grep -q "$image_name"; then
        echo "Image $image_name is present locally"
        
        if [ $image_name = ${SALT_MASTER_NAME} ]; then
            IS_MASTER_LOCAL=true
            echo "$image_name already exists"
        fi
        
    fi
done

if ${IS_MASTER_LOCAL}; then
    echo "Skippping the script "
    exit 0 
fi

if ! [ -d ${STORAGE_PATH} ]; then
    sudo mkdir -p ${STORAGE_PATH}
fi

# creating the pool
lxc storage create ${SALT_MASTER_POOL} dir source=${STORAGE_PATH}

#create network bridge
lxc network create ${SCRIPT_BRIDGE_NAME} ipv6.address=none ipv4.address=${IP_SUBNET} ipv4.nat=true

# creating needed profile
lxc profile create ${SCRIPT_PROFILE_NAME}

# editing needed profile
echo "config:
devices:
  ${IFACE}:
    name: ${IFACE}
    network: ${SCRIPT_BRIDGE_NAME}
    type: nic
  root:
    path: /
    pool: ${SALT_MASTER_POOL}
    type: disk
name: ${SCRIPT_PROFILE_NAME}" | lxc profile edit ${SCRIPT_PROFILE_NAME} 



#create salt-master container
lxc init ${OS} ${SALT_MASTER_NAME} --profile ${SCRIPT_PROFILE_NAME}
lxc network attach ${SCRIPT_BRIDGE_NAME} ${SALT_MASTER_NAME} ${IFACE}
lxc config device set ${SALT_MASTER_NAME} ${IFACE} ipv4.address ${IP}.2
lxc start ${SALT_MASTER_NAME} 
if lxc image list --format=json | jq -r '.[] | .fingerprint' | grep -q "$OS_FINGERPRINT"; then
    lxc image alias create ubuntu22.04 "$OS_FINGERPRINT"
fi
sudo lxc config device add ${SALT_MASTER_NAME} ${SALT_MASTER_NAME}-script-share disk source=${PWD}/scripts path=/lxd
sudo lxc exec ${SALT_MASTER_NAME} -- /bin/bash /lxd/${SALT_MASTER_NAME}.sh
    # save container as image
lxc stop ${SALT_MASTER_NAME}
lxc publish ${SALT_MASTER_NAME} --alias ${SALT_MASTER_NAME} 
lxc delete ${SALT_MASTER_NAME} --force


echo "Deleting Image $OS_FINGERPRINT"
sudo lxc image delete $OS_FINGERPRINT
echo "Deleting Profie $SCRIPT_PROFILE_NAME"
lxc profile delete $SCRIPT_PROFILE_NAME
echo "Deleting Network $SCRIPT_BRIDGE_NAME"
lxc network delete $SCRIPT_BRIDGE_NAME
echo "Deleting Pool $SALT_MASTER_POOL"
lxc storage delete $SALT_MASTER_POOL

echo "listing the images"
lxc image list --format=json | jq -r '.[] | .aliases' | jq -r '.[].name' 


