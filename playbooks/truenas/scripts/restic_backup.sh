#!/bin/bash

# Set up the environment
source /root/truenas/configs/.resticrc
export RESTIC_REPOSITORY=$RESTIC_REPOSITORY/$(basename "$1")

# Initialize the repository
restic init

# Perform the backup
restic backup "$1"

# Optional: Remove old snapshots (e.g., keep last 1 daily backups)
restic forget --keep-daily 1 --prune