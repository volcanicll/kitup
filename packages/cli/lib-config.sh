# Configuration management for kitup
# Handles loading and saving user configuration

CONFIG_DIR="${HOME}/.kitup"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
CONFIG_FILE_JSON="${CONFIG_DIR}/config.json"
PINNED_VERSIONS_FILE="${CONFIG_DIR}/pinned_versions"

# Default configuration values
DEFAULT_PARALLEL_JOBS=3
DEFAULT_BACKUP_ENABLED=false
DEFAULT_AUTO_INSTALL_MISSING=false

# Load configuration from file
load_config() {
    # Check for JSON config first
    if [ -f "$CONFIG_FILE_JSON" ]; then
        load_json_config
        return
    fi

    # Check for YAML config
    if [ -f "$CONFIG_FILE" ]; then
        load_yaml_config
        return
    fi

    # Use defaults
    return 0
}

# Load JSON configuration (simple parsing without jq)
load_json_config() {
    while IFS='=' read -r key value; do
        # Remove quotes and whitespace
        value=$(echo "$value" | sed 's/["'\'' ]//g' | sed 's/,$//')

        case "$key" in
            parallel_jobs)
                [ -n "$value" ] && PARALLEL_JOBS="$value"
                ;;
            auto_backup)
                [ "$value" = "true" ] && BACKUP_CONFIG=true
                ;;
            auto_install_missing)
                [ "$value" = "true" ] && INSTALL_MISSING=true
                ;;
            verbose)
                [ "$value" = "true" ] && VERBOSE=true
                ;;
            exclude_tools)
                KITUP_EXCLUDE_TOOLS="$value"
                ;;
            detect_new_tools)
                [ "$value" = "false" ] && KITUP_DETECT_NEW_TOOLS=false
                ;;
            changelog_count)
                [ -n "$value" ] && KITUP_CHANGELOG_COUNT="$value"
                ;;
        esac
    done < <(grep -E '^\s*"[^"]+"\s*:' "$CONFIG_FILE_JSON" | sed 's/.*"\([^"]*\)".*:\s*\(.*\)/\1=\2/')
}

# Load YAML configuration (simple parsing)
load_yaml_config() {
    while IFS=':' read -r key value; do
        # Trim whitespace
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^["\x27]//;s/["\x27]$//')

        case "$key" in
            parallel_jobs)
                [ -n "$value" ] && PARALLEL_JOBS="$value"
                ;;
            auto_backup)
                [ "$value" = "true" ] && BACKUP_CONFIG=true
                ;;
            auto_install_missing)
                [ "$value" = "true" ] && INSTALL_MISSING=true
                ;;
            verbose)
                [ "$value" = "true" ] && VERBOSE=true
                ;;
            exclude_tools)
                KITUP_EXCLUDE_TOOLS="$value"
                ;;
            detect_new_tools)
                [ "$value" = "false" ] && KITUP_DETECT_NEW_TOOLS=false
                ;;
            changelog_count)
                [ -n "$value" ] && KITUP_CHANGELOG_COUNT="$value"
                ;;
        esac
    done < "$CONFIG_FILE"
}

# Save configuration to JSON file
save_config() {
    local config_dir="$1"
    local parallel_jobs="${2:-$PARALLEL_JOBS}"
    local backup_enabled="${3:-$DEFAULT_BACKUP_ENABLED}"
    local auto_install="${4:-$DEFAULT_AUTO_INSTALL_MISSING}"

    mkdir -p "$config_dir"

    cat > "${config_dir}/config.json" << EOF
{
  "parallel_jobs": $parallel_jobs,
  "auto_backup": $backup_enabled,
  "auto_install_missing": $auto_install,
  "verbose": $VERBOSE,
  "exclude_tools": "$KITUP_EXCLUDE_TOOLS"
}
EOF
}

# Initialize default configuration
init_config() {
    if [ ! -f "$CONFIG_FILE_JSON" ] && [ ! -f "$CONFIG_FILE" ]; then
        save_config "$CONFIG_DIR" "$DEFAULT_PARALLEL_JOBS" "false" "false"
        print_info "Created default configuration at $CONFIG_FILE_JSON"
    fi
}

# Check if a tool is excluded
is_tool_excluded() {
    local tool="$1"
    if [ -n "$KITUP_EXCLUDE_TOOLS" ]; then
        echo "$KITUP_EXCLUDE_TOOLS" | grep -q "\\b${tool}\\b" && return 0
    fi
    return 1
}
