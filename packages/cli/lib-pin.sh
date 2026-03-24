# Version pinning management for kitup
# Allows users to pin specific versions of tools

PINNED_VERSIONS_FILE="${HOME}/.kitup/pinned_versions"

# Get pinned version for a tool
get_pinned_version() {
    local tool="$1"

    if [ ! -f "$PINNED_VERSIONS_FILE" ]; then
        return 1
    fi

    while read -r pinned_tool version; do
        if [ "$pinned_tool" = "$tool" ]; then
            echo "$version"
            return 0
        fi
    done < "$PINNED_VERSIONS_FILE"

    return 1
}

# Set pinned version for a tool
set_pinned_version() {
    local tool="$1"
    local version="$2"
    local config_dir

    config_dir=$(dirname "$PINNED_VERSIONS_FILE")
    mkdir -p "$config_dir"

    # Remove existing pin for this tool
    if [ -f "$PINNED_VERSIONS_FILE" ]; then
        local temp_file="${PINNED_VERSIONS_FILE}.tmp"
        grep -v "^${tool} " "$PINNED_VERSIONS_FILE" > "$temp_file" 2>/dev/null || true
        mv "$temp_file" "$PINNED_VERSIONS_FILE" 2>/dev/null || true
    fi

    # Add new pin
    echo "$tool $version" >> "$PINNED_VERSIONS_FILE"
    print_success "Pinned $tool to version $version"
}

# Remove pinned version for a tool
remove_pinned_version() {
    local tool="$1"

    if [ ! -f "$PINNED_VERSIONS_FILE" ]; then
        print_warning "No pinned versions found"
        return 1
    fi

    local temp_file="${PINNED_VERSIONS_FILE}.tmp"
    if grep -v "^${tool} " "$PINNED_VERSIONS_FILE" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$PINNED_VERSIONS_FILE"
        print_success "Removed version pin for $tool"
    else
        print_warning "No pinned version found for $tool"
        return 1
    fi
}

# List all pinned versions
list_pinned_versions() {
    if [ ! -f "$PINNED_VERSIONS_FILE" ]; then
        print_info "No pinned versions"
        return 0
    fi

    print_header "Pinned Versions"
    printf "\n"
    printf "%-15s %-15s\n" "Tool" "Pinned Version"
    printf "%-15s %-15s\n" "----" "--------------"

    while read -r tool version; do
        printf "%-15s %-15s\n" "$tool" "$version"
    done < "$PINNED_VERSIONS_FILE"

    printf "\n"
    print_info "Use 'kitup unpin <tool>' to remove a pin"
}

# Check if a tool has a pinned version
has_pinned_version() {
    local tool="$1"
    [ -f "$PINNED_VERSIONS_FILE" ] && grep -q "^${tool} " "$PINNED_VERSIONS_FILE"
}

# Get all pinned tools as a comma-separated list
get_pinned_tools() {
    if [ ! -f "$PINNED_VERSIONS_FILE" ]; then
        echo ""
        return
    fi

    local tools=""
    while read -r tool version; do
        if [ -n "$tools" ]; then
            tools="$tools,$tool"
        else
            tools="$tool"
        fi
    done < "$PINNED_VERSIONS_FILE"

    echo "$tools"
}
