#!/bin/bash

# Command locations
alias qm=/usr/sbin/qm

# Variables declarations
CONFIG_DIR=/etc/config
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
HOSTNAME=$(hostname)
PROXMOX_CONFIGS_JSON=${CONFIG_DIR}/${HOSTNAME}.json
PROXMOX_TMP_CONFIGS_JSON=${CONFIG_DIR}/${HOSTNAME}.json.tmp

# AWS S3 variables
AWS_S3_STORAGE_CLASS=STANDARD

# Import helpers
source $SCRIPT_DIR/proxmox_common.sh

# Usage function
function usage {
    echo "Usage: $0 [-b BUCKET] [-a ACCESS_KEY] [-s SECRET_KEY] [-r REGION]"
    echo "  -b BUCKET         S3 bucket name"
    echo "  -a ACCESS_KEY     AWS access key"
    echo "  -s SECRET_KEY     AWS secret key"
    echo "  -r REGION         AWS region"
    exit 1
}

# Check for the correct number of arguments
if [ "$#" -lt 8 ]; then
    usage
fi

# Parse arguments
while getopts "b:a:s:r:" opt; do
    case $opt in
        b) AWS_S3_BUCKET_NAME=$OPTARG ;;
        a) AWS_ACCESS_KEY_ID=$OPTARG ;;
        s) AWS_SECRET_ACCESS_KEY=$OPTARG ;;
        r) AWS_REGION=$OPTARG ;;
        *) usage ;;
    esac
done

function add_qm_config_to_json {
    # Arguments
    vm_id="$1"

    # Get the VM config as JSON
    qm_config=$(qm config $vm_id)
    qm_config_json=$(echo -e "$qm_config" | qm_config_as_json)

    # Only backup the VMs that have the "backup" tag
    if ! qm_config_has_backups_tag "$qm_config"; then
        echo "VM '$vm_id' does not have backups tag, skipping"
        return 1
    fi

    echo "Adding config for VM '$vm_id' to JSON"

    # Add the VM ID to the config
    qm_config_json=$(jq --argjson vm_id "$vm_id" '. += { vmid: $vm_id }' <<< "$qm_config_json")

    # Add target_node as current hostname to config
    qm_config_json=$(jq --arg target_node "$HOSTNAME" '. += { targetnode: $target_node }' <<< "$qm_config_json")

    # Append the JSON object to the JSON array
    jq --argjson config "$qm_config_json" '. += [$config]' $PROXMOX_CONFIGS_JSON > $PROXMOX_TMP_CONFIGS_JSON \
        && mv $PROXMOX_TMP_CONFIGS_JSON $PROXMOX_CONFIGS_JSON
}

# Make sure configs directory exists
mkdir -p $CONFIG_DIR

# Initialize an empty JSON array
echo "[]" > $PROXMOX_CONFIGS_JSON

# Get all the VM IDs
vm_ids=$(qm list | awk -F ' ' '{print $1}' | tail -n +2)

# Iterate over the VM IDs
for vm_id in $vm_ids
do
    # Add the VM config to the JSON file were building
    add_qm_config_to_json "$vm_id"
done

# Upload the configs file to S3
curl -v \
    --user "${AWS_ACCESS_KEY_ID}":"${AWS_SECRET_ACCESS_KEY}" \
    --aws-sigv4 "aws:amz:${AWS_REGION}:s3" \
    --upload-file "${PROXMOX_CONFIGS_JSON}" \
    -H "x-amz-storage-class: $AWS_S3_STORAGE_CLASS" \
    -H "x-amz-content-sha256: UNSIGNED-PAYLOAD" \
    -H "Content-Type: application/json" \
    https://${AWS_S3_BUCKET_NAME}.s3.${AWS_REGION}.amazonaws.com

# Check if the upload was successful
if [ $? -eq 0 ]; then
    echo "Proxmox config was successfully uploaded to S3."
else
    echo "There was an error uploading the Proxmox config to S3."
fi