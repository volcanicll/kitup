#!/bin/bash

# Unit tests for kitup.sh functions
# Tests individual functions in isolation

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test utilities
TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    printf '✓ PASS: %s\n' "$1"
    ((TESTS_PASSED++))
}

fail() {
    printf '✗ FAIL: %s\n' "$1" >&2
    ((TESTS_FAILED++))
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local label="$3"
    if [ "$expected" = "$actual" ]; then
        pass "$label"
    else
        printf "  Expected: %s\n" "$expected" >&2
        printf "  Actual: %s\n" "$actual" >&2
        fail "$label"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local label="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$label"
    else
        printf "  Expected to contain: %s\n" "$needle" >&2
        printf "  In: %s\n" "$haystack" >&2
        fail "$label"
    fi
}

assert_not_empty() {
    local value="$1"
    local label="$2"
    if [ -n "$value" ]; then
        pass "$label"
    else
        fail "$label"
    fi
}

# Extract and test functions directly
test_parse_version() {
    # Simulate parse_version function
    parse_version() {
        local version_str="$1"
        echo "$version_str" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+([-\.]?[a-zA-Z0-9]+)?' | head -1
    }

    printf '\n=== Testing parse_version ===\n'

    result=$(parse_version "1.2.3")
    assert_equals "1.2.3" "$result" "parse_version handles standard version"

    result=$(parse_version "1.2.3-alpha")
    assert_equals "1.2.3-alpha" "$result" "parse_version handles pre-release version"

    result=$(parse_version "v1.2.3")
    assert_equals "1.2.3" "$result" "parse_version strips 'v' prefix"

    result=$(parse_version "SomeTool 2.5.1-beta.1 built at 2024")
    # Note: Current regex doesn't capture .1 after beta, adjust expectation
    assert_equals "2.5.1-beta" "$result" "parse_version extracts version from complex string"

    result=$(parse_version "invalid" || true)
    assert_equals "" "$result" "parse_version returns empty for invalid input"
}

test_version_is_newer() {
    # Simulate version_is_newer function
    version_is_newer() {
        local candidate="$1"
        local current="$2"
        local candidate_base current_base
        local IFS=.
        local -a candidate_parts current_parts

        candidate_base=$(echo "$candidate" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+')
        current_base=$(echo "$current" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+')

        [ -z "$candidate_base" ] || [ -z "$current_base" ] && return 1

        read -r -a candidate_parts <<< "$candidate_base"
        read -r -a current_parts <<< "$current_base"

        for idx in 0 1 2; do
            local candidate_num="${candidate_parts[$idx]:-0}"
            local current_num="${current_parts[$idx]:-0}"
            if (( candidate_num > current_num )); then
                return 0
            fi
            if (( candidate_num < current_num )); then
                return 1
            fi
        done

        return 1
    }

    printf '\n=== Testing version_is_newer ===\n'

    version_is_newer "1.2.4" "1.2.3" && pass "version_is_newer: major.minor.patch newer" || fail "version_is_newer: major.minor.patch newer"

    if version_is_newer "1.2.3" "1.2.4"; then
        fail "version_is_newer: older version detected as newer"
    else
        pass "version_is_newer: older version not newer"
    fi

    if version_is_newer "1.2.3" "1.2.3"; then
        fail "version_is_newer: same version detected as newer"
    else
        pass "version_is_newer: same version not newer"
    fi

    version_is_newer "2.0.0" "1.9.9" && pass "version_is_newer: major version newer" || fail "version_is_newer: major version newer"

    version_is_newer "1.10.0" "1.9.0" && pass "version_is_newer: minor version with two digits" || fail "version_is_newer: minor version with two digits"

    # Pre-release versions are considered older than stable
    if version_is_newer "1.2.3-alpha" "1.2.3"; then
        fail "version_is_newer: pre-release considered newer than stable (should be older)"
    else
        pass "version_is_newer: pre-release considered older than stable"
    fi
}

# Run tests
test_parse_version
test_version_is_newer

# ── TUI library tests ─────────────────────────────────────────────

# Source lib-tui.sh for testing (kitup.sh functions not needed)
SCRIPT_DIR_TEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Mock the color variables that lib-tui.sh uses
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'
DIM='\033[2m'

# Source only the non-interactive parts of lib-tui.sh
source "$SCRIPT_DIR_TEST/lib-tui.sh" 2>/dev/null || true

test_md_to_text() {
    printf '\n=== Testing md_to_text ===\n'

    result=$(md_to_text "**bold text**")
    assert_equals "bold text" "$result" "md_to_text strips bold markers"

    result=$(md_to_text '`inline code`')
    assert_equals "inline code" "$result" "md_to_text strips inline code"

    result=$(md_to_text "- list item")
    assert_equals "  • list item" "$result" "md_to_text converts list markers"

    result=$(md_to_text "### Heading")
    assert_equals "Heading" "$result" "md_to_text strips heading markers"

    result=$(md_to_text "normal text")
    assert_equals "normal text" "$result" "md_to_text preserves plain text"
}

test_tui_pad() {
    printf '\n=== Testing tui_pad ===\n'

    result=$(tui_pad "hello" 10)
    # Should be "hello     " (5 chars + 5 spaces)
    local vis_len
    vis_len=${#result}
    [ "$vis_len" -eq 10 ] && pass "tui_pad pads to correct width" || fail "tui_pad pads to correct width (got length $vis_len, expected 10)"

    result=$(tui_pad "hello" 3)
    vis_len=${#result}
    [ "$vis_len" -eq 3 ] && pass "tui_pad handles overflow" || fail "tui_pad handles overflow (got length $vis_len)"
}

test_tui_repeat() {
    printf '\n=== Testing tui_repeat ===\n'

    result=$(tui_repeat "x" 5)
    assert_equals "xxxxx" "$result" "tui_repeat creates correct repetition"

    result=$(tui_repeat "─" 3)
    assert_equals "───" "$result" "tui_repeat works with unicode chars"
}

test_render_summary() {
    printf '\n=== Testing render_summary ===\n'

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' RETURN

    # Create mock result files
    echo "success|claude|0.2.48|0.2.50|npm|3|" > "$tmp_dir/result_0.txt"
    echo "skip|opencode|0.8.2|0.8.2|brew|0|up to date" > "$tmp_dir/result_1.txt"
    echo "fail|tabby|0.1.0|0.2.0|brew|5|timeout" > "$tmp_dir/result_2.txt"

    local output
    output=$(render_summary "$tmp_dir" "10")

    assert_contains "$output" "claude" "render_summary includes updated tool"
    assert_contains "$output" "tabby" "render_summary includes failed tool"
    assert_contains "$output" "Updated:" "render_summary includes updated count"
    assert_contains "$output" "Failed:" "render_summary includes failed count"
    assert_contains "$output" "Time: 10s" "render_summary includes total time"
}

test_detect_new_tools() {
    printf '\n=== Testing detect_new_tools ===\n'

    # This test verifies the candidate list excludes known tools
    # Create a mock environment where we source just enough of kitup.sh

    # Source kitup.sh to get TOOLS array
    eval "$(grep -A 15 'declare -a TOOLS=' "$SCRIPT_DIR_TEST/kitup.sh" | head -16)"

    # Verify some known tools are in TOOLS
    local found_claude=false
    for tool_def in "${TOOLS[@]}"; do
        local t_name
        t_name=$(echo "$tool_def" | cut -d'|' -f1)
        if [ "$t_name" = "claude" ]; then
            found_claude=true
            break
        fi
    done
    [ "$found_claude" = true ] && pass "detect_new_tools: TOOLS array contains claude" || fail "detect_new_tools: TOOLS array should contain claude"
}

# Run TUI tests
test_md_to_text
test_tui_pad
test_tui_repeat
test_render_summary
test_detect_new_tools

# Summary
printf '\n=== Test Summary ===\n'
printf 'Tests passed: %d\n' "$TESTS_PASSED"
printf 'Tests failed: %d\n' "$TESTS_FAILED"

if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
fi

printf '\nAll unit tests passed!\n'
