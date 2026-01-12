#!/bin/bash
# Bootible - File Push Functions
# ===============================
# Functions for pushing files and directories to Android devices.

# Push a single file or directory
push_item() {
    local local_path="$1"
    local device_path="$2"
    local description="$3"

    if [[ ! -e "$local_path" ]]; then
        echo -e "  ${YELLOW}!${NC} Source not found: $local_path"
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        if [[ -d "$local_path" ]]; then
            echo -e "  ${YELLOW}[DRY RUN]${NC} Would push directory: $local_path -> $device_path"
        else
            echo -e "  ${YELLOW}[DRY RUN]${NC} Would push file: $local_path -> $device_path"
        fi
        return 0
    fi

    echo -e "  ${BLUE}>${NC} Pushing: $(basename "$local_path") -> $device_path"

    # Create parent directory on device
    local parent_dir
    parent_dir=$(dirname "$device_path")
    run_adb_shell "mkdir -p '$parent_dir'" 2>/dev/null

    if [[ -d "$local_path" ]]; then
        # Push directory recursively
        if run_adb push "$local_path/." "$device_path/" 2>&1 | tail -1 | grep -q "pushed"; then
            echo -e "    ${GREEN}+${NC} Directory pushed"
            return 0
        else
            echo -e "    ${RED}X${NC} Failed to push directory"
            return 1
        fi
    else
        # Push single file
        if run_adb push "$local_path" "$device_path" 2>&1 | grep -q "pushed"; then
            echo -e "    ${GREEN}+${NC} File pushed"
            return 0
        else
            echo -e "    ${RED}X${NC} Failed to push file"
            return 1
        fi
    fi
}

# Push all configured files
push_all_files() {
    echo ""
    echo -e "${CYAN}---------------------------------------------------------------${NC}"
    echo -e "${CYAN}                       File Push                               ${NC}"
    echo -e "${CYAN}---------------------------------------------------------------${NC}"

    local pushed=0
    local skipped=0
    local failed=0

    # Get list of file category keys
    local file_keys
    file_keys=$(yq '.files | keys | .[]' "$SELECTED_CONFIG" 2>/dev/null)

    if [[ -z "$file_keys" ]]; then
        echo -e "${YELLOW}!${NC} No files configured"
        return 0
    fi

    for key in $file_keys; do
        # Skip the 'custom' key - handled separately
        if [[ "$key" == "custom" ]]; then
            continue
        fi

        # Check if enabled
        local enabled
        enabled=$(yq ".files.$key.enabled // false" "$SELECTED_CONFIG" 2>/dev/null)

        if [[ "$enabled" != "true" ]]; then
            ((skipped++))
            continue
        fi

        # Get paths
        local local_path device_path description
        local_path=$(yq ".files.$key.local_path // \"\"" "$SELECTED_CONFIG" 2>/dev/null)
        device_path=$(yq ".files.$key.device_path // \"\"" "$SELECTED_CONFIG" 2>/dev/null)
        description=$(yq ".files.$key.description // \"\"" "$SELECTED_CONFIG" 2>/dev/null)

        if [[ -z "$local_path" || -z "$device_path" ]]; then
            echo -e "${YELLOW}!${NC} Skipping $key: missing path configuration"
            ((skipped++))
            continue
        fi

        # Make local path absolute (relative to private/)
        local full_local_path="$BOOTIBLE_DIR/private/$local_path"

        echo ""
        echo -e "${BLUE}$key:${NC} ${description:-$key}"

        if push_item "$full_local_path" "$device_path" "$description"; then
            ((pushed++))
        else
            ((failed++))
        fi
    done

    # Handle custom file entries
    push_custom_files

    echo ""
    echo -e "${BLUE}File Push Summary:${NC}"
    echo -e "  Pushed: $pushed"
    echo -e "  Skipped: $skipped"
    echo -e "  Failed: $failed"
}

# Push custom file entries (the 'custom' array in config)
push_custom_files() {
    local custom_count
    custom_count=$(yq '.files.custom | length' "$SELECTED_CONFIG" 2>/dev/null || echo 0)

    if [[ $custom_count -eq 0 ]]; then
        return 0
    fi

    echo ""
    echo -e "${BLUE}Custom files:${NC}"

    for ((i=0; i<custom_count; i++)); do
        local local_path device_path
        local_path=$(yq ".files.custom[$i].local_path // \"\"" "$SELECTED_CONFIG" 2>/dev/null)
        device_path=$(yq ".files.custom[$i].device_path // \"\"" "$SELECTED_CONFIG" 2>/dev/null)

        if [[ -z "$local_path" || -z "$device_path" ]]; then
            continue
        fi

        # Make local path absolute (relative to private/)
        local full_local_path="$BOOTIBLE_DIR/private/$local_path"

        push_item "$full_local_path" "$device_path"
    done
}

# Pull a file from device to local
pull_item() {
    local device_path="$1"
    local local_path="$2"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY RUN]${NC} Would pull: $device_path -> $local_path"
        return 0
    fi

    echo -e "  ${BLUE}>${NC} Pulling: $device_path -> $local_path"

    # Create local parent directory
    mkdir -p "$(dirname "$local_path")"

    if run_adb pull "$device_path" "$local_path" 2>&1 | grep -q "pulled"; then
        echo -e "    ${GREEN}+${NC} Pulled successfully"
        return 0
    else
        echo -e "    ${RED}X${NC} Failed to pull"
        return 1
    fi
}

# List files in a device directory
list_device_files() {
    local device_path="$1"

    run_adb_shell "ls -la '$device_path'" 2>/dev/null
}

# Check if a file exists on device
device_file_exists() {
    local device_path="$1"

    local result
    result=$(run_adb_shell "[ -e '$device_path' ] && echo 'exists'" 2>/dev/null | tr -d '\r\n')
    [[ "$result" == "exists" ]]
}

# Get available storage on device
get_device_storage() {
    run_adb_shell "df -h /sdcard" 2>/dev/null | tail -1
}
