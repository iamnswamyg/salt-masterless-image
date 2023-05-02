#!/bin/bash

SCRIPT_PREFIX="salt"
OS=images:ubuntu/jammy
OS_FINGERPRINT="39da8bdecb9450521ec97683265fbc51fa1f29c0eabae102e7be78e787788047"
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
IS_MASTER_LOCAL=false
IS_MINION_LOCAL=false

# check if jq exists
if ! snap list | grep jq >>/dev/null 2>&1; then
  sudo snap install jq 
fi
# check if lxd exists
if ! snap list | grep lxd >>/dev/null 2>&1; then
  sudo snap install lxd 
fi

image_names=("${SALT_MASTER_NAME}" "${SALT_MINION_NAME}")

# Loop through the list of items
for image_name in "${image_names[@]}"
do
    if lxc image list --format=json | jq -r '.[] | .aliases' | jq -r '.[].name' | grep -q "$image_name"; then
        echo "Image $image_name is present locally"
        

        if [ $image_name = ${SALT_MASTER_NAME} ]; then
            MASTER_IMAGE=$image_name
            IS_MASTER_LOCAL=true
            echo "Using image $image_name for master"
        fi
        if [ $image_name = ${SALT_MINION_NAME} ]; then
            MINION_IMAGE=$image_name
            IS_MINION_LOCAL=true
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
if lxc image list --format=json | jq -r '.[] | .fingerprint' | grep -q "$OS_FINGERPRINT"; then
    lxc image alias create ubuntu22.04 "$OS_FINGERPRINT"
fi
sudo lxc config device add ${SALT_MASTER_NAME} ${SALT_MASTER_NAME}-script-share disk source=${PWD}/scripts path=/lxd
sudo lxc config device add ${SALT_MASTER_NAME} ${SALT_MASTER_NAME}-salt-share disk source=${PWD}/salt-root/salt path=/srv/salt
sudo lxc config device add ${SALT_MASTER_NAME} ${SALT_MASTER_NAME}-pillar-share disk source=${PWD}/salt-root/pillar path=/srv/pillar
sudo lxc exec ${SALT_MASTER_NAME} -- /bin/bash /lxd/${SALT_MASTER_NAME}.sh
if ! ${IS_MASTER_LOCAL}; then
    # save container as image
    lxc stop ${SALT_MASTER_NAME}
    lxc publish ${SALT_MASTER_NAME} --alias ${SALT_MASTER_NAME} 
    lxc start ${SALT_MASTER_NAME}
    IS_MASTER_LOCAL=true
fi
sleep 5

# Loop through the salt-minions and create the minions
for client in "${clients[@]}"; do
  vno=$(echo "$client" | awk '{print $1}' | awk -F% '{print $2}')
  ip=$(echo "$client" | awk '{print $2}' | awk -F% '{print $2}')
  ker=$(echo "$client" | awk '{print $3}' | awk -F% '{print $2}')
  vname=${SALT_MINION_NAME}${vno}
    
    echo ${IS_MINION_LOCAL}

    if ${IS_MINION_LOCAL}; then
        ker=${SALT_MINION_NAME}
    fi

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
    
    if ! ${IS_MINION_LOCAL}; then
        IS_MINION_LOCAL=true
        lxc stop ${vname}
        lxc publish ${vname} --alias ${SALT_MINION_NAME} 
        lxc start ${vname}
    fi
    sleep 10
done







