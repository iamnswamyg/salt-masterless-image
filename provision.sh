#!/bin/bash

SCRIPT_PREFIX="lxd-basic"
OS=images:ubuntu/jammy
STORAGE_PATH="/data/lxd/"${SCRIPT_PREFIX}
IP="10.120.11"
IFACE="eth0"
IP_SUBNET=${IP}".1/24"
LXD_BASIC_POOL=${SCRIPT_PREFIX}"-pool"
SCRIPT_PROFILE_NAME=${SCRIPT_PREFIX}"-profile"
SCRIPT_BRIDGE_NAME=${SCRIPT_PREFIX}"-br"
LXD_BASIC_CLIENT_NAME=${SCRIPT_PREFIX}"-client"


LXD_BASIC_SERVER_NAME=${SCRIPT_PREFIX}"-server"
declare -a clients=("vname%${LXD_BASIC_CLIENT_NAME}1 ip%${IP}.3 ker%${OS}" 
                    "vname%${LXD_BASIC_CLIENT_NAME}2 ip%${IP}.4 ker%${OS}")

if ! [ -d ${STORAGE_PATH} ]; then
    sudo mkdir -p ${STORAGE_PATH}
fi

# creating the pool
lxc storage create ${LXD_BASIC_POOL} dir source=${STORAGE_PATH}

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
    pool: ${LXD_BASIC_POOL}
    type: disk
name: ${SCRIPT_PROFILE_NAME}" | lxc profile edit ${SCRIPT_PROFILE_NAME} 


#create lxd-basic-server container
lxc init ${OS} ${LXD_BASIC_SERVER_NAME} --profile ${SCRIPT_PROFILE_NAME}
lxc network attach ${SCRIPT_BRIDGE_NAME} ${LXD_BASIC_SERVER_NAME} ${IFACE}
lxc config device set ${LXD_BASIC_SERVER_NAME} ${IFACE} ipv4.address ${IP}.2
lxc start ${LXD_BASIC_SERVER_NAME} 




# Loop through the data and extract the values
for client in "${clients[@]}"; do
  vname=$(echo "$client" | awk '{print $1}' | awk -F% '{print $2}')
  ip=$(echo "$client" | awk '{print $2}' | awk -F% '{print $2}')
  ker=$(echo "$client" | awk '{print $3}' | awk -F% '{print $2}')
    
    #create lxd-basic-client container
    lxc init ${ker} ${vname} --profile ${SCRIPT_PROFILE_NAME}
    lxc network attach ${SCRIPT_BRIDGE_NAME} ${vname} ${IFACE}
    lxc config device set ${vname} ${IFACE} ipv4.address ${ip}
    lxc start ${vname} 
done







