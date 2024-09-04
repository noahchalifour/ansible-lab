PROXMOX_BACKUPS_TAG="backups"

function qm_config_has_backups_tag {
    config_output="$1"

        # Process each line of the config output
    while IFS= read -r line; do
        # Split the line into key and value based on the first ':' character
        key="${line%%:*}"
        value="${line#*:}"

        # Trim whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        if [ "$key" == "tags" ] && [[ "$value" =~ $PROXMOX_BACKUPS_TAG ]]; then
            return 0
        fi
    done <<< "$config_output"

    return 1
}

function qm_config_as_json {
    # Initialize an empty JSON object
    json_output="{"

    # Process each line of the config output
    while IFS= read -r line; do
        # Split the line into key and value based on the first ':' character
        key="${line%%:*}"
        value="${line#*:}"

        # Trim whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        # Add the key-value pair to the JSON object
        json_output+="\"$key\":\"$value\","
    done

    # Remove the trailing comma and close the JSON object
    json_output="${json_output%,}}"

    # Echo the JSON formatted config
    echo "$json_output" | jq .
}