#!/bin/bash
# Bootible - Settings Configuration Functions
# ============================================
# Functions for configuring Android system settings via ADB.

# Configure a single setting
configure_setting() {
    local namespace="$1"  # system, secure, or global
    local key="$2"
    local value="$3"

    # Skip empty values
    if [[ -z "$value" || "$value" == "null" || "$value" == '""' ]]; then
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY RUN]${NC} Would set $namespace/$key = $value"
        return 0
    fi

    echo -e "  ${BLUE}>${NC} Setting $namespace/$key = $value"

    # Apply the setting (suppress verbose output)
    local old_show_commands="${SHOW_COMMANDS:-}"
    SHOW_COMMANDS=""

    if adb -s "$CONNECTED_DEVICE" shell "settings put $namespace $key $value" 2>/dev/null; then
        # Verify the setting was applied
        local current
        current=$(adb -s "$CONNECTED_DEVICE" shell "settings get $namespace $key" 2>/dev/null | tr -d '\r\n')
        SHOW_COMMANDS="$old_show_commands"

        if [[ "$current" == "$value" ]]; then
            echo -e "    ${GREEN}+${NC} Set successfully"
            return 0
        else
            echo -e "    ${YELLOW}!${NC} Value may not have been applied (device reports: $current)"
            return 0  # Don't fail - some settings are device-specific
        fi
    else
        SHOW_COMMANDS="$old_show_commands"
        echo -e "    ${RED}X${NC} Failed to set $key"
        return 1
    fi
}

# Apply all settings from config
apply_all_settings() {
    echo ""
    echo -e "${CYAN}---------------------------------------------------------------${NC}"
    echo -e "${CYAN}                   Settings Configuration                      ${NC}"
    echo -e "${CYAN}---------------------------------------------------------------${NC}"

    local applied=0
    local skipped=0
    local failed=0

    # Process each namespace
    for namespace in system secure global; do
        echo ""
        echo -e "${BLUE}$namespace settings:${NC}"

        # Get all keys for this namespace
        local keys
        keys=$(yq -r ".settings.$namespace | keys | .[]" "$SELECTED_CONFIG" 2>/dev/null) || keys=""

        if [[ -z "$keys" ]]; then
            echo "  (none configured)"
            continue
        fi

        # Iterate over newline-separated keys
        while IFS= read -r key; do
            [[ -z "$key" ]] && continue

            local value
            value=$(yq -r ".settings.$namespace.$key // \"\"" "$SELECTED_CONFIG" 2>/dev/null)

            # Remove quotes if present
            value="${value%\"}"
            value="${value#\"}"

            if [[ -z "$value" || "$value" == "null" || "$value" == "" ]]; then
                ((skipped++))
                continue
            fi

            if configure_setting "$namespace" "$key" "$value"; then
                ((applied++))
            else
                ((failed++))
            fi
        done <<< "$keys"
    done

    # Apply device profile settings if specified
    apply_profile_settings

    echo ""
    echo -e "${BLUE}Settings Summary:${NC}"
    echo -e "  Applied: $applied"
    echo -e "  Skipped: $skipped"
    echo -e "  Failed: $failed"
}

# Apply settings from device profile
apply_profile_settings() {
    local profile
    profile=$(yq '.device_profile // ""' "$SELECTED_CONFIG" 2>/dev/null)

    if [[ -z "$profile" || "$profile" == "null" || "$profile" == '""' ]]; then
        return 0
    fi

    echo ""
    echo -e "${BLUE}Applying profile settings: $profile${NC}"

    # Check if profile exists - look in both selected config and base config
    local base_config="$BOOTIBLE_DIR/config/android/config.yml"
    local profile_config=""
    local profile_exists

    # Check selected config first
    profile_exists=$(yq ".profiles.$profile // null" "$SELECTED_CONFIG" 2>/dev/null)
    if [[ "$profile_exists" != "null" ]]; then
        profile_config="$SELECTED_CONFIG"
    else
        # Check base config
        profile_exists=$(yq ".profiles.$profile // null" "$base_config" 2>/dev/null)
        if [[ "$profile_exists" != "null" ]]; then
            profile_config="$base_config"
        fi
    fi

    if [[ -z "$profile_config" ]]; then
        echo -e "  ${YELLOW}!${NC} Profile not found: $profile"
        return 0
    fi

    # Apply profile settings (these override base settings)
    for namespace in system secure global; do
        local keys
        keys=$(yq -r ".profiles.$profile.settings.$namespace | keys | .[]" "$profile_config" 2>/dev/null) || keys=""

        if [[ -z "$keys" ]]; then
            continue
        fi

        # Iterate over newline-separated keys
        while IFS= read -r key; do
            [[ -z "$key" ]] && continue

            local value
            value=$(yq -r ".profiles.$profile.settings.$namespace.$key // \"\"" "$profile_config" 2>/dev/null)

            # Remove quotes if present
            value="${value%\"}"
            value="${value#\"}"

            if [[ -n "$value" && "$value" != "null" ]]; then
                configure_setting "$namespace" "$key" "$value"
            fi
        done <<< "$keys"
    done
}

# Get current value of a setting
get_setting() {
    local namespace="$1"
    local key="$2"

    run_adb_shell "settings get $namespace $key" 2>/dev/null | tr -d '\r\n'
}

# Reset a setting to default
reset_setting() {
    local namespace="$1"
    local key="$2"

    echo -e "  ${BLUE}>${NC} Resetting $namespace/$key"
    run_adb_shell "settings delete $namespace $key" 2>/dev/null
}
