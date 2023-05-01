#!/bin/bash


image_names=("salt-master" "salt-minion")

# Loop through the list of items
for image_name in "${image_names[@]}"
do
    if lxc image list | grep -q "$image_name"; then
        echo "Image $image_name is present locally"
    else
        echo "Image $image_name is importing locally"
        lxc image import $image_name.zip --alias $image_name
    fi
done

SCRIPT_PREFIX="salt"


STORAGE_PATH="/data/lxd/"${SCRIPT_PREFIX}


if ! [ -d ${STORAGE_PATH} ]; then
    sudo mkdir -p ${STORAGE_PATH}
fi

SALT_POOL=${SCRIPT_PREFIX}"-pool"
lxc storage create ${SALT_POOL} dir source=${STORAGE_PATH}

# creating needed profile
SCRIPT_PROFILE_NAME=${SCRIPT_PREFIX}"-profile"
lxc profile create ${SCRIPT_PROFILE_NAME}

# editing needed profile
SCRIPT_PROFILE_PATH=${PWD}"/files/"${SCRIPT_PREFIX}"-profile.yaml"
lxc profile edit ${SCRIPT_PROFILE_NAME} < ${SCRIPT_PROFILE_PATH}
# lxc profile show ${SCRIPT_PROFILE_NAME}

#create network bridge
SCRIPT_BRIDGE_NAME=${SCRIPT_PREFIX}"-br"
lxc network create ${SCRIPT_BRIDGE_NAME} ipv6.address=none ipv4.address=10.120.11.1/24 ipv4.nat=true

#create salt-master container
SALT_MASTER_NAME=${SCRIPT_PREFIX}"-master"
lxc init ${SALT_MASTER_NAME} ${SALT_MASTER_NAME} 
lxc network attach ${SCRIPT_BRIDGE_NAME} ${SALT_MASTER_NAME} eth0
lxc config device set ${SALT_MASTER_NAME} eth0 ipv4.address 10.120.11.2
lxc start ${SALT_MASTER_NAME}

#create salt-minion container
SALT_MINION_NAME=${SCRIPT_PREFIX}"-minion"
lxc init ${SALT_MINION_NAME} ${SALT_MINION_NAME} 
lxc network attach ${SCRIPT_BRIDGE_NAME} ${SALT_MINION_NAME} eth0
lxc config device set ${SALT_MINION_NAME} eth0 ipv4.address 10.120.11.3
lxc start ${SALT_MINION_NAME} 







