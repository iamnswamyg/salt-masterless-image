#!/bin/bash

SCRIPT_PREFIX="salt"
STORAGE_PATH="/data/lxd/"${SCRIPT_PREFIX}
IP="10.120.11"
IFACE="eth0"
IP_SUBNET=${IP}".1/24"
SALT_MINION_POOL=${SCRIPT_PREFIX}"-pool"
SCRIPT_PROFILE_NAME=${SCRIPT_PREFIX}"-profile"
SCRIPT_BRIDGE_NAME=${SCRIPT_PREFIX}"-br"
SALT_MINION_NAME=${SCRIPT_PREFIX}"-masterless"
SALT_MINION_IMAGE=${SCRIPT_PREFIX}"-minion"
IS_MINION_LOCAL=false


# check if jq exists
if ! snap list | grep jq >>/dev/null 2>&1; then
  sudo snap install jq 
fi
# check if lxd exists
if ! snap list | grep lxd >>/dev/null 2>&1; then
  sudo snap install lxd 
fi

image_names=("${SALT_MINION_IMAGE}" )

# Loop through the list of items
for image_name in "${image_names[@]}"
do
    if lxc image list --format=json | jq -r '.[] | .aliases' | jq -r '.[].name' | grep -q "$image_name"; then
        echo "Image $image_name is present locally"
        
        if [ $image_name = ${SALT_MINION_IMAGE} ]; then
            IS_MINION_LOCAL=true
            echo "$image_name already exists"
        fi
        
    fi
done

if ! ${IS_MINION_LOCAL}; then
    echo "Skippping the script "
    exit 0 
fi

# preparing master conf file
# preparing master conf file
echo "file_client: local
file_roots:
  base:
    - /srv/salt
    - /srv/formulas/tomcat-formula">${PWD}/scripts/saltconfig/minion.local.conf





if ! [ -d ${STORAGE_PATH} ]; then
    sudo mkdir -p ${STORAGE_PATH}
fi

# creating the pool
lxc storage create ${SALT_MINION_POOL} dir source=${STORAGE_PATH}

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
    pool: ${SALT_MINION_POOL}
    type: disk
name: ${SCRIPT_PROFILE_NAME}" | lxc profile edit ${SCRIPT_PROFILE_NAME} 



#create salt-master container
lxc init ${SALT_MINION_IMAGE} ${SALT_MINION_NAME} --profile ${SCRIPT_PROFILE_NAME}
lxc network attach ${SCRIPT_BRIDGE_NAME} ${SALT_MINION_NAME} ${IFACE}
lxc config device set ${SALT_MINION_NAME} ${IFACE} ipv4.address ${IP}.2
lxc start ${SALT_MINION_NAME} 
sudo lxc config device add ${SALT_MINION_NAME} ${SALT_MINION_NAME}-script-share disk source=${PWD}/scripts path=/lxd
sudo lxc exec ${SALT_MINION_NAME} -- /bin/bash /lxd/${SALT_MINION_IMAGE}.sh
    # save container as image
lxc stop ${SALT_MINION_NAME}
lxc publish ${SALT_MINION_NAME} --alias ${SALT_MINION_NAME} 
lxc delete ${SALT_MINION_NAME} --force


echo "Deleting Profie $SCRIPT_PROFILE_NAME"
lxc profile delete $SCRIPT_PROFILE_NAME
echo "Deleting Network $SCRIPT_BRIDGE_NAME"
lxc network delete $SCRIPT_BRIDGE_NAME
echo "Deleting Pool $SALT_MINION_POOL"
lxc storage delete $SALT_MINION_POOL

echo "listing the images"
lxc image list --format=json | jq -r '.[] | .aliases' | jq -r '.[].name' 


