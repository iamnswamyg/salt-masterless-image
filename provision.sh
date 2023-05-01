#!/bin/bash

SCRIPT_PREFIX="salt"
OS=images:ubuntu/jammy
STORAGE_PATH="/data/lxd/"${SCRIPT_PREFIX}
IP="10.120.11"
IFACE="eth0"
IP_SUBNET=${IP}".1/24"
SALT_MASTER_POOL=${SCRIPT_PREFIX}"-pool"
SCRIPT_PROFILE_NAME=${SCRIPT_PREFIX}"-profile"
SCRIPT_BRIDGE_NAME=${SCRIPT_PREFIX}"-br"
SALT_MINION_NAME=${SCRIPT_PREFIX}"-minion"
SALT_MASTER_NAME=${SCRIPT_PREFIX}"-master"
MASTER_IMAGE=${OS}
MINION_IMAGE=${OS}
MASTER_IS_LOCAL=false
MINION_IS_LOCAL=false

image_names=("salt-master" "salt-minion")

# Loop through the list of items
for image_name in "${image_names[@]}"
do
    if lxc image list --format=json | jq -r '.[] | .aliases' | jq -r '.[].name' | grep -q "$image_name"; then
        echo "Image $image_name is present locally"
        

        if [ $image_name = "salt-master" ]; then
            MASTER_IMAGE=$image_name
            MASTER_IS_LOCAL=true
            echo "Using image $image_name for master"
        fi
        if [ $image_name = "salt-minion" ]; then
            MINION_IMAGE=$image_name
            MINION_IS_LOCAL=true
            echo "Using image $image_name for minion(s)"
        fi
    fi
done

# preparing master conf file
echo "interface: ${IP}.2
auto_accept: True">${PWD}/scripts/saltconfig/master.local.conf




declare -a clients=("vno%1 ip%${IP}.3 ker%${MINION_IMAGE}" 
                    "vno%2 ip%${IP}.4 ker%${MINION_IMAGE}")

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
lxc init ${MASTER_IMAGE} ${SALT_MASTER_NAME} --profile ${SCRIPT_PROFILE_NAME}
lxc network attach ${SCRIPT_BRIDGE_NAME} ${SALT_MASTER_NAME} ${IFACE}
lxc config device set ${SALT_MASTER_NAME} ${IFACE} ipv4.address ${IP}.2
lxc start ${SALT_MASTER_NAME} 

sudo lxc config device add ${SALT_MASTER_NAME} ${SALT_MASTER_NAME}-script-share disk source=${PWD}/scripts path=/lxd
sudo lxc config device add ${SALT_MASTER_NAME} ${SALT_MASTER_NAME}-salt-share disk source=${PWD}/salt-root/salt path=/srv/salt
sudo lxc config device add ${SALT_MASTER_NAME} ${SALT_MASTER_NAME}-pillar-share disk source=${PWD}/salt-root/pillar path=/srv/pillar
sudo lxc exec ${SALT_MASTER_NAME} -- /bin/bash /lxd/${SALT_MASTER_NAME}.sh
if ! ${MASTER_IS_LOCAL}; then
    # save container as image
    lxc publish ${SALT_MASTER_NAME} --alias ${SALT_MASTER_NAME} 
fi

IS_MINION_LOCAL=false


# Loop through the data and extract the values
for client in "${clients[@]}"; do
  vno=$(echo "$client" | awk '{print $1}' | awk -F% '{print $2}')
  ip=$(echo "$client" | awk '{print $2}' | awk -F% '{print $2}')
  ker=$(echo "$client" | awk '{print $3}' | awk -F% '{print $2}')
  vname=${SALT_MINION_NAME}${vno}
   
    # preparing minion conf file
    echo "master: ${IP}.2
    id: ${vname}">${PWD}/scripts/saltconfig/minion.local.conf
    
    #create salt-minion container
    lxc init ${ker} ${vname} --profile ${SCRIPT_PROFILE_NAME}
    lxc network attach ${SCRIPT_BRIDGE_NAME} ${vname} ${IFACE}
    lxc config device set ${vname} ${IFACE} ipv4.address ${ip}
    lxc start ${vname} 

    sudo lxc config device add ${vname} ${vname}-script-share disk source=${PWD}/scripts path=/lxd
    sudo lxc exec ${vname} -- /bin/bash /lxd/${SALT_MINION_NAME}.sh
    if ! ${MASTER_IS_LOCAL}; then
        if ! ${IS_MINION_LOCAL}; then
                IS_MINION_LOCAL=true
                lxc publish ${vname} --alias ${SALT_MINION_NAME} 
        fi
    fi
done







