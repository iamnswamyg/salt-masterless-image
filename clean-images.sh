#!/bin/bash

SCRIPT_PREFIX="salt"
SALT_MINION_NAME=${SCRIPT_PREFIX}"-minion"
SALT_MASTER_NAME=${SCRIPT_PREFIX}"-master"

image_names=("${SALT_MASTER_NAME}" "${SALT_MINION_NAME}")

# Loop through the list of items
for image_name in "${image_names[@]}"
do
    if lxc image list --format=json | jq -r '.[] | .aliases' | jq -r '.[].name' | grep -q "$image_name"; then
        echo "Deleting Image $image_name is locally"
        sudo lxc image delete $image_name
    fi
done

image_fingerprint="39da8bdecb9450521ec97683265fbc51fa1f29c0eabae102e7be78e787788047"
if lxc image list --format=json | jq -r '.[] | .fingerprint' | grep -q "$image_fingerprint"; then
        echo "Deleting Image $image_fingerprint is locally"
        sudo lxc image delete $image_fingerprint
fi
echo "listing the images"
lxc image list --format=json | jq -r '.[] | .aliases' | jq -r '.[].name' 