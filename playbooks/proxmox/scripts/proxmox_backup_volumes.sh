#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Import helpers
source $SCRIPT_DIR/proxmox_common.sh

# Variables declaration
IMAGES_DIR=/var/lib/vz/images
LVM_REGEX="^local-lvm:([a-z0-9\-]*)"

# AWS S3 variables
AWS_S3_QCOW2_PATH=/qcow2
AWS_S3_VOLUME_STORAGE_CLASS=INTELLIGENT_TIERING

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

# Function to backup a single volume to S3
function backup_volume {
    volume="$1"
    qcow_name="$2"

    # Export volume
    qemu-img convert -O qcow2 \
        "/dev/pve/$volume" \
        $IMAGES_DIR/$qcow_name.qcow2
    
    # Compress disk
    xz -0 -zv -T 0 $IMAGES_DIR/$qcow_name.qcow2

    # Upload the compressed disk file to S3
    /snap/bin/aws s3 cp \
        --region $AWS_REGION \
        "$IMAGES_DIR/$qcow_name.qcow2.xz" \
        "s3://${AWS_S3_BUCKET_NAME}${AWS_S3_QCOW2_PATH}/${qcow_name}.qcow2.xz"

    # Check if the upload was successful
    if [ $? -eq 0 ]; then
        echo "Volume was successfully uploaded to S3."
    else
        echo "There was an error uploading the volume to S3."
    fi

    # Remove backup files
    rm -f $IMAGES_DIR/$qcow_name.qcow2
    rm -f $IMAGES_DIR/$qcow_name.qcow2.xz
}

function backup_volumes_for_vm {
    # Arguments
    vm_id="$1"

    # Get the config for the VM
    config_output=$(/usr/sbin/qm config $vm_id)

    # Only backup the VMs that have the "backup" tag
    if ! qm_config_has_backups_tag "$config_output"; then
        echo "VM '$vm_id' does not have backups tag, skipping"
        return 1
    fi

    # Do a clean shutdown of the VM
    /usr/sbin/qm shutdown "$vm_id"

    echo "Backing up all volumes for VM '$vm_id'"

    # Process each line of the config output to find volumes
    while IFS= read -r line; do
        # Split the line into key and value based on the first ':' character
        key="${line%%:*}"
        value="${line#*:}"

        # Trim whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        # Check if value contains "local-lvm:"
        if [[ $value =~ $LVM_REGEX ]]; then
            # Extract the part that matches the regex (the volume)
            volume=${BASH_REMATCH[1]}

            echo "Backing up volume: $volume"

            # Back up the volume to S3 (use volume ID as .qcow2 name)
            backup_volume "$volume" "$volume"
        fi
    done <<< "$config_output"

    # Restart the VM once backups are done
    /usr/sbin/qm start "$vm_id"
}

# Export credentials
export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"

# Get all the VM IDs
vm_ids=$(/usr/sbin/qm list | awk -F ' ' '{print $1}' | tail -n +2)

# Iterate over the VM IDs
for vm_id in $vm_ids
do
    # Back up all the volumes
    backup_volumes_for_vm "$vm_id"
done
