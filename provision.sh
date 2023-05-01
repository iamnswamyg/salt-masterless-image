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


SALT_MASTER_SERVER_NAME=${SCRIPT_PREFIX}"-master"
declare -a clients=("vname%${SALT_MINION_NAME}1 ip%${IP}.3 ker%${OS}" 
                    "vname%${SALT_MINION_NAME}2 ip%${IP}.4 ker%${OS}")

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
lxc init ${OS} ${SALT_MASTER_SERVER_NAME} --profile ${SCRIPT_PROFILE_NAME}
lxc network attach ${SCRIPT_BRIDGE_NAME} ${SALT_MASTER_SERVER_NAME} ${IFACE}
lxc config device set ${SALT_MASTER_SERVER_NAME} ${IFACE} ipv4.address ${IP}.2
lxc start ${SALT_MASTER_SERVER_NAME} 

sudo lxc config device add ${SALT_MASTER_SERVER_NAME} ${SALT_MASTER_SERVER_NAME}-script-share disk source=${PWD}/scripts path=/lxd
sudo lxc config device add ${SALT_MASTER_SERVER_NAME} ${SALT_MASTER_SERVER_NAME}-salt-share disk source=${PWD}/salt-root/salt path=/srv/salt
sudo lxc config device add ${SALT_MASTER_SERVER_NAME} ${SALT_MASTER_SERVER_NAME}-pillar-share disk source=${PWD}/salt-root/pillar path=/srv/pillar
sudo lxc exec ${SALT_MASTER_SERVER_NAME} -- /bin/bash /lxd/${SALT_MASTER_SERVER_NAME}.sh



# Loop through the data and extract the values
for client in "${clients[@]}"; do
  vname=$(echo "$client" | awk '{print $1}' | awk -F% '{print $2}')
  ip=$(echo "$client" | awk '{print $2}' | awk -F% '{print $2}')
  ker=$(echo "$client" | awk '{print $3}' | awk -F% '{print $2}')
    
    #create salt-minion container
    lxc init ${ker} ${vname} --profile ${SCRIPT_PROFILE_NAME}
    lxc network attach ${SCRIPT_BRIDGE_NAME} ${vname} ${IFACE}
    lxc config device set ${vname} ${IFACE} ipv4.address ${ip}
    lxc start ${vname} 

    sudo lxc config device add ${vname} ${vname}-script-share disk source=${PWD}/scripts path=/lxd
    sudo lxc exec ${vname} -- /bin/bash /lxd/${vname}.sh
done







