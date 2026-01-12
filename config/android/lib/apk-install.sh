#!/bin/bash
# Bootible - APK Installation Functions
# ======================================
# Functions for installing APKs from various sources.

# Get keep_apks setting
should_keep_apks() {
    local keep
    keep=$(yq '.keep_apks // false' "$SELECTED_CONFIG" 2>/dev/null)
    [[ "$keep" == "true" ]]
}

# Download APK from URL
download_apk() {
    local url="$1"
    local dest="$2"

    echo -e "  ${BLUE}>${NC} Downloading from $url"

    if ! curl -fsSL "$url" -o "$dest" 2>/dev/null; then
        echo -e "  ${RED}X${NC} Download failed"
        return 1
    fi

    echo -e "  ${GREEN}+${NC} Downloaded to $dest"
    return 0
}

# Get latest APK URL from F-Droid
get_fdroid_apk_url() {
    local package="$1"
    local fdroid_repo
    fdroid_repo=$(yq '.fdroid.repo_url // "https://f-droid.org/repo"' "$SELECTED_CONFIG" 2>/dev/null)

    # F-Droid index format: package_versioncode.apk
    # We need to fetch the index to get the latest version
    local index_url="${fdroid_repo}/index-v2.json"

    # Try to get the package info from F-Droid API
    local apk_name
    apk_name=$(curl -fsSL "https://f-droid.org/api/v1/packages/${package}" 2>/dev/null | jq -r '.suggestedVersionCode // empty')

    if [[ -n "$apk_name" ]]; then
        echo "${fdroid_repo}/${package}_${apk_name}.apk"
    else
        # Fallback: try common naming convention
        echo "${fdroid_repo}/${package}.apk"
    fi
}

# Install a single APK
install_apk() {
    local name="$1"
    local source="$2"
    local location="$3"
    local package_name="$4"
    local permissions="$5"  # comma-separated

    echo ""
    echo -e "${BLUE}>${NC} Installing $name..."

    # Check if already installed
    if [[ -n "$package_name" ]] && is_package_installed "$package_name"; then
        echo -e "  ${GREEN}+${NC} $name already installed"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY RUN]${NC} Would install: $name"
        echo -e "    Source: $source"
        echo -e "    Location: $location"
        return 0
    fi

    local apk_path=""
    local cleanup_apk=false

    case "$source" in
        url)
            apk_path="/tmp/bootible_${name}.apk"
            if ! download_apk "$location" "$apk_path"; then
                return 1
            fi
            cleanup_apk=true
            ;;

        local)
            apk_path="$BOOTIBLE_DIR/private/$location"
            if [[ ! -f "$apk_path" ]]; then
                echo -e "  ${RED}X${NC} APK not found: $apk_path"
                return 1
            fi
            ;;

        fdroid)
            local fdroid_url
            fdroid_url=$(get_fdroid_apk_url "$location")
            apk_path="/tmp/bootible_${name}.apk"
            echo -e "  ${BLUE}>${NC} Fetching from F-Droid: $fdroid_url"
            if ! download_apk "$fdroid_url" "$apk_path"; then
                return 1
            fi
            cleanup_apk=true
            ;;

        *)
            echo -e "  ${RED}X${NC} Unknown source type: $source"
            return 1
            ;;
    esac

    # Install the APK
    echo -e "  ${BLUE}>${NC} Installing APK..."
    if run_adb install -r "$apk_path" 2>&1 | grep -q "Success"; then
        echo -e "  ${GREEN}+${NC} $name installed"

        # Grant permissions if specified
        if [[ -n "$permissions" && -n "$package_name" ]]; then
            IFS=',' read -ra perms <<< "$permissions"
            for perm in "${perms[@]}"; do
                grant_permission "$package_name" "$perm"
            done
        fi

        # Cleanup downloaded APK
        if [[ "$cleanup_apk" == "true" ]] && ! should_keep_apks; then
            rm -f "$apk_path"
        fi

        return 0
    else
        echo -e "  ${RED}X${NC} Failed to install $name"

        # Cleanup on failure
        if [[ "$cleanup_apk" == "true" ]]; then
            rm -f "$apk_path"
        fi

        return 1
    fi
}

# Install all enabled APKs from config
install_all_apks() {
    echo ""
    echo -e "${CYAN}---------------------------------------------------------------${NC}"
    echo -e "${CYAN}                    APK Installation                           ${NC}"
    echo -e "${CYAN}---------------------------------------------------------------${NC}"

    # Get list of APK keys
    local apk_keys
    apk_keys=$(yq '.apks | keys | .[]' "$SELECTED_CONFIG" 2>/dev/null)

    if [[ -z "$apk_keys" ]]; then
        echo -e "${YELLOW}!${NC} No APKs configured"
        return 0
    fi

    local installed=0
    local skipped=0
    local failed=0

    for key in $apk_keys; do
        # Check if enabled
        local enabled
        enabled=$(yq ".apks.$key.enabled // false" "$SELECTED_CONFIG" 2>/dev/null)

        if [[ "$enabled" != "true" ]]; then
            ((skipped++))
            continue
        fi

        # Get APK details
        local source location package_name permissions
        source=$(yq ".apks.$key.source // \"\"" "$SELECTED_CONFIG" 2>/dev/null)
        package_name=$(yq ".apks.$key.package_name // \"\"" "$SELECTED_CONFIG" 2>/dev/null)

        # Get location based on source type
        case "$source" in
            url)
                location=$(yq ".apks.$key.url // \"\"" "$SELECTED_CONFIG" 2>/dev/null)
                ;;
            local)
                location=$(yq ".apks.$key.path // \"\"" "$SELECTED_CONFIG" 2>/dev/null)
                ;;
            fdroid)
                location=$(yq ".apks.$key.package // \"\"" "$SELECTED_CONFIG" 2>/dev/null)
                ;;
        esac

        # Get permissions to grant
        permissions=$(yq ".apks.$key.grant_permissions | join(\",\")" "$SELECTED_CONFIG" 2>/dev/null)

        if [[ -z "$source" || -z "$location" ]]; then
            echo -e "${YELLOW}!${NC} Skipping $key: missing source or location"
            ((skipped++))
            continue
        fi

        # Install the APK
        if install_apk "$key" "$source" "$location" "$package_name" "$permissions"; then
            ((installed++))
        else
            ((failed++))
        fi
    done

    echo ""
    echo -e "${BLUE}APK Summary:${NC}"
    echo -e "  Installed: $installed"
    echo -e "  Skipped: $skipped"
    echo -e "  Failed: $failed"
}
