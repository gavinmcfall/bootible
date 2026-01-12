#!/bin/bash
# Bootible - ADB Helper Functions
# ================================
# Common ADB wrapper functions for Android provisioning.

# Get verbose setting
is_verbose() {
    local verbose
    verbose=$(yq '.verbose // false' "$SELECTED_CONFIG" 2>/dev/null)
    [[ "$verbose" == "true" ]]
}

# Get show_commands setting
should_show_commands() {
    local show
    show=$(yq '.show_commands // false' "$SELECTED_CONFIG" 2>/dev/null)
    [[ "$show" == "true" ]]
}

# Run an ADB command
run_adb() {
    local args=("$@")

    if should_show_commands; then
        echo -e "  ${CYAN}adb ${args[*]}${NC}"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY RUN]${NC} adb ${args[*]}"
        return 0
    fi

    if [[ -n "$CONNECTED_DEVICE" ]]; then
        adb -s "$CONNECTED_DEVICE" "${args[@]}"
    else
        adb "${args[@]}"
    fi
}

# Run an ADB shell command
run_adb_shell() {
    local cmd="$1"

    if should_show_commands; then
        echo -e "  ${CYAN}adb shell $cmd${NC}"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY RUN]${NC} adb shell $cmd"
        return 0
    fi

    if [[ -n "$CONNECTED_DEVICE" ]]; then
        adb -s "$CONNECTED_DEVICE" shell "$cmd"
    else
        adb shell "$cmd"
    fi
}

# Check if a package is installed
is_package_installed() {
    local package_name="$1"

    local result
    if [[ -n "$CONNECTED_DEVICE" ]]; then
        result=$(adb -s "$CONNECTED_DEVICE" shell pm list packages 2>/dev/null | grep -c "package:$package_name")
    else
        result=$(adb shell pm list packages 2>/dev/null | grep -c "package:$package_name")
    fi

    [[ "$result" -gt 0 ]]
}

# Get device model
get_device_model() {
    if [[ -n "$CONNECTED_DEVICE" ]]; then
        adb -s "$CONNECTED_DEVICE" shell getprop ro.product.model 2>/dev/null | tr -d '\r\n'
    else
        adb shell getprop ro.product.model 2>/dev/null | tr -d '\r\n'
    fi
}

# Get Android version
get_android_version() {
    if [[ -n "$CONNECTED_DEVICE" ]]; then
        adb -s "$CONNECTED_DEVICE" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r\n'
    else
        adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r\n'
    fi
}

# Get device manufacturer
get_device_manufacturer() {
    if [[ -n "$CONNECTED_DEVICE" ]]; then
        adb -s "$CONNECTED_DEVICE" shell getprop ro.product.manufacturer 2>/dev/null | tr -d '\r\n'
    else
        adb shell getprop ro.product.manufacturer 2>/dev/null | tr -d '\r\n'
    fi
}

# Check if device is connected
is_device_connected() {
    local devices
    devices=$(adb devices 2>/dev/null | grep -v "^List" | grep -v "^$" | grep -v "offline")

    if [[ -n "$CONNECTED_DEVICE" ]]; then
        echo "$devices" | grep -q "$CONNECTED_DEVICE"
    else
        [[ -n "$devices" ]]
    fi
}

# Grant a permission to an app
grant_permission() {
    local package_name="$1"
    local permission="$2"

    echo -e "  ${BLUE}>${NC} Granting $permission to $package_name"
    run_adb_shell "pm grant $package_name $permission" 2>/dev/null || true
}

# Start an app by package name
start_app() {
    local package_name="$1"

    echo -e "  ${BLUE}>${NC} Starting $package_name"
    run_adb_shell "monkey -p $package_name -c android.intent.category.LAUNCHER 1" 2>/dev/null || true
}

# Stop an app by package name
stop_app() {
    local package_name="$1"

    echo -e "  ${BLUE}>${NC} Stopping $package_name"
    run_adb_shell "am force-stop $package_name" 2>/dev/null || true
}

# Wait for device to be ready
wait_for_device() {
    local timeout="${1:-30}"
    local waited=0

    echo -e "${BLUE}>${NC} Waiting for device..."

    while [[ $waited -lt $timeout ]]; do
        if is_device_connected; then
            echo -e "${GREEN}+${NC} Device ready"
            return 0
        fi
        sleep 1
        ((waited++))
    done

    echo -e "${RED}X${NC} Device not ready after ${timeout}s"
    return 1
}
