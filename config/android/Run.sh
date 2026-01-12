#!/bin/bash
# Bootible - Android Provisioning Engine
# =======================================
# This script is sourced by targets/android.sh after device connection.
# It reads config and executes provisioning tasks.
#
# Environment variables available:
#   BOOTIBLE_DIR      - Path to bootible installation
#   SELECTED_CONFIG   - Path to config.yml being used
#   SELECTED_INSTANCE - Name of device instance
#   CONNECTED_DEVICE  - ADB device identifier (e.g., 192.168.1.100:5555)
#   DRY_RUN           - "true" or "false"
#   GITHUB_TOKEN      - GitHub token if authenticated

# Source helper libraries
source "$BOOTIBLE_DIR/config/android/lib/adb-helpers.sh"
source "$BOOTIBLE_DIR/config/android/lib/apk-install.sh"
source "$BOOTIBLE_DIR/config/android/lib/settings.sh"
source "$BOOTIBLE_DIR/config/android/lib/files.sh"

# =============================================================================
# CONFIGURATION LOADING
# =============================================================================

load_config() {
    if [[ ! -f "$SELECTED_CONFIG" ]]; then
        echo -e "${RED}X${NC} Config file not found: $SELECTED_CONFIG"
        return 1
    fi

    # Load base config
    local base_config="$BOOTIBLE_DIR/config/android/config.yml"

    # Check for device profile
    local device_profile
    device_profile=$(yq '.device_profile // ""' "$SELECTED_CONFIG" 2>/dev/null)

    if [[ -n "$device_profile" && "$device_profile" != "null" && "$device_profile" != '""' ]]; then
        echo -e "${BLUE}>${NC} Applying device profile: $device_profile"
    fi

    return 0
}

# =============================================================================
# MAIN PROVISIONING FLOW
# =============================================================================

run_main_provisioning() {
    echo -e "${CYAN}===============================================================${NC}"
    echo -e "${CYAN}                 Android Provisioning                          ${NC}"
    echo -e "${CYAN}===============================================================${NC}"
    echo ""

    # Load configuration
    load_config || return 1

    # Get feature flags
    local install_apks configure_settings push_files execute_commands
    install_apks=$(yq '.install_apks // false' "$SELECTED_CONFIG" 2>/dev/null)
    configure_settings=$(yq '.configure_settings // false' "$SELECTED_CONFIG" 2>/dev/null)
    push_files=$(yq '.push_files // false' "$SELECTED_CONFIG" 2>/dev/null)
    execute_commands=$(yq '.execute_commands // false' "$SELECTED_CONFIG" 2>/dev/null)

    # Show what will be done
    echo -e "${BLUE}Provisioning plan:${NC}"
    [[ "$execute_commands" == "true" ]] && echo "  - Run pre-provisioning commands"
    [[ "$install_apks" == "true" ]] && echo "  - Install APKs"
    [[ "$configure_settings" == "true" ]] && echo "  - Configure settings"
    [[ "$push_files" == "true" ]] && echo "  - Push files"
    [[ "$execute_commands" == "true" ]] && echo "  - Run post-provisioning commands"
    echo ""

    # Execute pre-provisioning commands
    if [[ "$execute_commands" == "true" ]]; then
        run_pre_commands
    fi

    # Install APKs
    if [[ "$install_apks" == "true" ]]; then
        install_all_apks
    fi

    # Configure settings
    if [[ "$configure_settings" == "true" ]]; then
        apply_all_settings
    fi

    # Push files
    if [[ "$push_files" == "true" ]]; then
        push_all_files
    fi

    # Execute post-provisioning commands
    if [[ "$execute_commands" == "true" ]]; then
        run_post_commands
    fi

    echo ""
    echo -e "${GREEN}+${NC} Provisioning complete"
}

# =============================================================================
# COMMAND EXECUTION
# =============================================================================

run_pre_commands() {
    local cmd_count
    cmd_count=$(yq '.commands.pre | length' "$SELECTED_CONFIG" 2>/dev/null || echo 0)

    if [[ $cmd_count -eq 0 ]]; then
        return 0
    fi

    echo ""
    echo -e "${BLUE}>${NC} Running pre-provisioning commands..."

    for ((i=0; i<cmd_count; i++)); do
        local cmd
        cmd=$(yq ".commands.pre[$i]" "$SELECTED_CONFIG" 2>/dev/null)

        if [[ -z "$cmd" || "$cmd" == "null" ]]; then
            continue
        fi

        run_adb_shell "$cmd"
    done
}

run_post_commands() {
    local cmd_count
    cmd_count=$(yq '.commands.post | length' "$SELECTED_CONFIG" 2>/dev/null || echo 0)

    if [[ $cmd_count -eq 0 ]]; then
        return 0
    fi

    echo ""
    echo -e "${BLUE}>${NC} Running post-provisioning commands..."

    for ((i=0; i<cmd_count; i++)); do
        local cmd
        cmd=$(yq ".commands.post[$i]" "$SELECTED_CONFIG" 2>/dev/null)

        if [[ -z "$cmd" || "$cmd" == "null" ]]; then
            continue
        fi

        run_adb_shell "$cmd"
    done
}

# =============================================================================
# ENTRY POINT
# =============================================================================

# Run the main provisioning
run_main_provisioning
