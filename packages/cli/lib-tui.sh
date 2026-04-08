# TUI library for kitup
# Provides terminal helpers, box drawing, summary table, progress indicator, and interactive TUI

# ── Terminal helpers ──────────────────────────────────────────────

# Check if running in an interactive terminal
tui_is_interactive() {
    [ -t 0 ]
}

# Get terminal width (columns)
tui_cols() {
    local cols
    cols=$(tput cols 2>/dev/null) || cols=80
    echo "${cols:-80}"
}

# Get terminal height (lines)
tui_lines() {
    local lines
    lines=$(tput lines 2>/dev/null) || lines=24
    echo "${lines:-24}"
}

# Terminal cursor control
tui_hide_cursor()  { printf '\033[?25l'; }
tui_show_cursor()  { printf '\033[?25h'; }
tui_cursor_up()    { printf '\033[%dA' "${1:-1}"; }
tui_cursor_down()  { printf '\033[%dB' "${1:-1}"; }
tui_cursor_home()  { printf '\033[H'; }
tui_clear_line()   { printf '\033[2K\r'; }
tui_clear_screen() { printf '\033[2J\033[H'; }

# Additional color codes for TUI
DIM='\033[2m'
REVERSE='\033[7m'
UNDERLINE='\033[4m'

# Status symbols
SYM_CHECK='\u2713'     # ✓
SYM_CROSS='\u2717'     # ✗
SYM_BULLET='\u25CF'    # ●
SYM_CIRCLE='\u25CB'    # ○
SYM_ARROW_UP='\u2191'  # ↑
SYM_ARROW_DN='\u2193'  # ↓
SYM_PIN='\u2691'       # ⚑
SYM_SPINNER_1='\u2807' # ⟳ (braille pattern)
SYM_DASH='\u2500'      # ─
SYM_SELECTED='\u25C9'  # ◉
SYM_UNSELECTED='\u25CB' # ○
SYM_BOX_TL='\u250C'    # ┌
SYM_BOX_TR='\u2510'    # ┐
SYM_BOX_BL='\u2514'    # └
SYM_BOX_BR='\u2518'    # ┘
SYM_BOX_H='\u2500'     # ─
SYM_BOX_V='\u2502'     # │
SYM_BOX_LJ='\u251C'    # ├
SYM_BOX_RJ='\u2524'    # ┤

# ── Box drawing ───────────────────────────────────────────────────

# Print a horizontal rule within a box
# Usage: tui_box_rule [width] [left_char] [right_char]
tui_box_rule() {
    local width="${1:-$(tui_cols)}"
    local left="${2:-├}"
    local right="${3:-┤}"
    local inner=$((width - 2))
    printf '%s' "$left"
    printf '%*s' "$inner" '' | tr ' ' '─'
    printf '%s\n' "$right"
}

# Print a box header line
# Usage: tui_box_header "title" [width]
tui_box_header() {
    local title="$1"
    local width="${2:-$(tui_cols)}"
    local inner=$((width - 2))
    printf '┌─ %s' "$title"
    local title_len=${#title}
    # title already printed with "┌─ " prefix (3 chars), need remaining padding
    local used=$((title_len + 3))
    local remaining=$((inner - title_len - 1))
    if [ "$remaining" -gt 0 ]; then
        printf '%*s' "$remaining" '' | tr ' ' '─'
    fi
    printf '┐\n'
}

# Print a box footer line
# Usage: tui_box_footer [width]
tui_box_footer() {
    local width="${1:-$(tui_cols)}"
    local inner=$((width - 2))
    printf '└'
    printf '%*s' "$inner" '' | tr ' ' '─'
    printf '┘\n'
}

# Print a box content line (left + right margin)
# Usage: tui_box_line "content" [width]
tui_box_line() {
    local content="$1"
    local width="${2:-$(tui_cols)}"
    local inner=$((width - 4))
    # Strip ANSI codes for length calculation
    local visible
    visible=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*m//g')
    local vis_len=${#visible}
    local padding=$((inner - vis_len))
    if [ "$padding" -lt 0 ]; then padding=0; fi
    printf '│ %s%*s │\n' "$(echo -e "$content")" "$padding" ''
}

# ── Text formatting helpers ───────────────────────────────────────

# Repeat a character N times
tui_repeat() {
    local char="$1"
    local count="$2"
    printf '%*s' "$count" '' | tr ' ' "$char"
}

# Pad a string to a given width (left-align, truncate if needed)
tui_pad() {
    local str="$1"
    local width="$2"
    local visible
    visible=$(echo -e "$str" | sed 's/\x1b\[[0-9;]*m//g')
    local vis_len=${#visible}
    if [ "$vis_len" -gt "$width" ]; then
        # Truncate visible text, keep ANSI codes from original
        printf '%s' "$(echo -e "$str" | cut -c1-$width)"
    else
        local padding=$((width - vis_len))
        printf '%s%*s' "$(echo -e "$str")" "$padding" ''
    fi
}

# Center text in a given width
tui_center() {
    local text="$1"
    local width="$2"
    local visible
    visible=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local vis_len=${#visible}
    local left_pad=$(( (width - vis_len) / 2 ))
    [ "$left_pad" -lt 0 ] && left_pad=0
    printf '%*s%s' "$left_pad" '' "$(echo -e "$text")"
}

# ── Markdown to text conversion ───────────────────────────────────

# Strip markdown to plain text for changelog display
md_to_text() {
    local input="$1"
    echo "$input" | sed \
        -e 's/^###* //' \
        -e 's/\*\*\([^*]*\)\*\*/\1/g' \
        -e 's/__\([^_]*\)__/\1/g' \
        -e 's/\*\([^*]*\)\*/\1/g' \
        -e 's/_\([^_]*\)_/\1/g' \
        -e 's/`\([^`]*\)`/\1/g' \
        -e 's/^\* /  • /' \
        -e 's/^- /  • /' \
        -e 's/^[[:space:]][-][[:space:]]/  • /' \
        -e '/^---*$/d'
}

# ── Summary table ─────────────────────────────────────────────────

# Render update results summary
# Reads result files from $1 (directory containing result_*.txt files)
# Each file format: status|name|local_ver|latest_ver|method|elapsed|error
render_summary() {
    local results_dir="$1"
    local total_time="${2:-0}"
    local width=60

    local updated=0 skipped=0 failed=0
    local updated_rows="" skipped_rows="" failed_rows=""

    if [ ! -d "$results_dir" ]; then
        return
    fi

    for result_file in "$results_dir"/result_*.txt; do
        [ -f "$result_file" ] || continue
        local line
        line=$(cat "$result_file")
        IFS='|' read -r status name local_ver latest_ver method elapsed error <<< "$line"

        case "$status" in
            success)
                updated=$((updated + 1))
                updated_rows="$updated_rows
$(tui_box_line "  ${GREEN}✓${NC}  $(tui_pad "$name" 10) $(tui_pad "$local_ver → $latest_ver" 18) $(tui_pad "$method" 8) ${elapsed}s")"
                ;;
            skip)
                skipped=$((skipped + 1))
                local reason="${error:-skipped}"
                skipped_rows="$skipped_rows
$(tui_box_line "  ${DIM}-  $(tui_pad "$name" 10) $(tui_pad "$local_ver" 18) $(tui_pad "$method" 8) $reason")"
                ;;
            fail)
                failed=$((failed + 1))
                failed_rows="$failed_rows
$(tui_box_line "  ${RED}✗${NC}  $(tui_pad "$name" 10) $(tui_pad "${error:-failed}" 18) $(tui_pad "$method" 8)")"
                ;;
        esac
    done

    printf '\n'
    tui_box_header "Update Results"
    printf '%s\n' "$updated_rows"
    [ -n "$skipped_rows" ] && printf '%s\n' "$skipped_rows"
    [ -n "$failed_rows" ] && printf '%s\n' "$failed_rows"
    tui_box_rule "$width"
    tui_box_line "  ${GREEN}Updated: ${updated}${NC}  │  Skipped: ${skipped}  │  ${RED}Failed: ${failed}${NC}  │  Time: ${total_time}s"
    tui_box_footer "$width"
    printf '\n'
}

# ── Progress indicator ────────────────────────────────────────────

# Render progress for parallel updates
# Arguments: results_dir job_count [current_tool]
# Reads job status files from results_dir
render_progress() {
    local results_dir="$1"
    local job_count="$2"
    local total="$3"
    local width=60

    local completed=0
    local i=0

    while [ "$i" -lt "$job_count" ]; do
        local status_file="$results_dir/job_${i}_status"
        local job_file="$results_dir/job_${i}"
        local name=""
        local method=""
        local state="queued"
        local elapsed=""

        if [ -f "$job_file" ]; then
            IFS='|' read -r name method _ <<< "$(cat "$job_file")"
        fi

        if [ -f "$status_file" ]; then
            local status_line
            status_line=$(cat "$status_file")
            local result
            result=$(echo "$status_line" | cut -d'|' -f1)
            case "$result" in
                success)
                    state="done"
                    completed=$((completed + 1))
                    elapsed=$(echo "$status_line" | cut -d'|' -f3)
                    printf '  %s✓%s %s %s %s %ss\n' "$GREEN" "$NC" "$(tui_pad "$name" 10)" "$(tui_pad "done" 18)" "$(tui_pad "$method" 8)" "${elapsed:--}"
                    ;;
                fail)
                    state="fail"
                    completed=$((completed + 1))
                    local err_msg
                    err_msg=$(echo "$status_line" | cut -d'|' -f2)
                    printf '  %s✗%s %s %s\n' "$RED" "$NC" "$(tui_pad "$name" 10)" "$(tui_pad "${err_msg:-failed}" 18)"
                    ;;
                running)
                    state="running"
                    printf '  %s⟳%s %s %s %s\n' "$YELLOW" "$NC" "$(tui_pad "$name" 10)" "$(tui_pad "updating via $method..." 18)" "$(tui_pad "$method" 8)"
                    ;;
            esac
        else
            if [ -n "$name" ]; then
                printf '  %s○%s %s %s\n' "$DIM" "$NC" "$(tui_pad "$name" 10)" "$(tui_pad "queued" 18)"
            fi
        fi

        i=$((i + 1))
    done

    printf '  [%d/%d complete]\n' "$completed" "$total"
}

# ── Interactive TUI ───────────────────────────────────────────────

# Show interactive TUI for tool selection
# Arguments: results_dir (to store selected tools for update)
show_tui() {
    local results_dir="$1"
    local width
    width=$(tui_cols)

    # State
    local cursor=0
    local -a tool_names=()
    local -a tool_installed=()
    local -a tool_needs_update=()
    local -a tool_selected=()
    local -a tool_versions=()
    local -a tool_latest=()
    local -a tool_methods=()
    local tool_count=0

    # Detect new tools for display
    local new_tools_output=""
    new_tools_output=$(detect_new_tools 2>/dev/null || true)

    # Gather tool data
    for tool_def in "${TOOLS[@]}"; do
        IFS='|' read -r name cmd npm_pkg brew_formula pipx_pkg uv_pkg github_repo install_url <<< "$tool_def"

        local installed="no"
        local method="-"
        local local_ver="-"
        local latest_ver="-"
        local needs="no"

        if command_exists "$cmd"; then
            installed="yes"
            method=$(detect_install_method "$cmd" "$npm_pkg" "$brew_formula" "$pipx_pkg" "$uv_pkg")
            local_ver=$(get_local_version "$cmd")
            latest_ver=$(get_latest_version "$method" "$npm_pkg" "$brew_formula" "$pipx_pkg" "$uv_pkg" "$github_repo")

            if [ -n "$latest_ver" ] && [ "$local_ver" != "$latest_ver" ]; then
                needs="yes"
            fi
        fi

        tool_names+=("$name")
        tool_installed+=("$installed")
        tool_needs_update+=("$needs")
        tool_selected+=("$needs")  # pre-select tools that need update
        tool_versions+=("$local_ver")
        tool_latest+=("$latest_ver")
        tool_methods+=("$method")
        tool_count=$((tool_count + 1))
    done

    # Compute visible items (installed tools first, then not-installed, then new)
    local total_items=$tool_count

    # Trap to restore terminal on exit
    tui_restore() {
        tui_show_cursor
        printf '\033[?25h'
        # Re-enable echo in case it was disabled
        stty echo 2>/dev/null || true
    }
    trap tui_restore EXIT INT TERM

    tui_hide_cursor
    stty -echo 2>/dev/null || true

    # Main render loop
    while true; do
        # Clear screen and render
        tui_clear_screen

        # Header
        printf '┌─ kitup v%s ' "$VERSION"
        local header_pad=$((width - 16 - ${#VERSION}))
        [ "$header_pad" -lt 0 ] && header_pad=0
        tui_repeat '─' "$header_pad"
        printf '┐\n'

        tui_box_line "${BOLD}${CYAN}AI Tools Status${NC}   [j/k] navigate  [Space] select  [Enter] update  [q] quit"
        tui_box_rule "$width"

        # Tool rows
        local i=0
        while [ "$i" -lt "$tool_count" ]; do
            local marker="○"
            local status_icon=""
            local version_str=""

            if [ "${tool_installed[$i]}" = "yes" ]; then
                if [ "${tool_needs_update[$i]}" = "yes" ]; then
                    # Needs update
                    if [ "${tool_selected[$i]}" = "yes" ]; then
                        marker="◉"
                    else
                        marker="○"
                    fi
                    status_icon="${YELLOW}● needs update${NC}"
                    version_str="${tool_versions[$i]} → ${tool_latest[$i]}"
                else
                    # Up to date
                    marker="○"
                    status_icon="${GREEN}✓ up to date${NC}"
                    version_str="${tool_versions[$i]}"
                fi
            else
                # Not installed
                marker="${DIM}○${NC}"
                status_icon="${DIM}not installed${NC}"
                version_str="-"
            fi

            # Highlight current cursor position
            local line_prefix=" "
            if [ "$i" -eq "$cursor" ]; then
                line_prefix="${REVERSE} ${NC}"
            fi

            local name_col="$(tui_pad "${tool_names[$i]}" 10)"
            local ver_col="$(tui_pad "$version_str" 20)"
            local method_col="$(tui_pad "${tool_methods[$i]}" 8)"

            tui_box_line " $line_prefix $marker  ${name_col} ${ver_col} ${method_col} ${status_icon}"
            i=$((i + 1))
        done

        # New tools section
        if [ -n "$new_tools_output" ]; then
            tui_box_rule "$width"
            tui_box_line "${DIM}── new tools detected ──────────────────────────────────────${NC}"
            while IFS='|' read -r nname ncmd nver npath; do
                [ -z "$nname" ] && continue
                tui_box_line "  ${YELLOW}⚑${NC}  $(tui_pad "$nname" 10) $(tui_pad "${nver:--}" 12) ${DIM}consider adding support${NC}"
            done <<< "$new_tools_output"
        fi

        tui_box_rule "$width"

        # Count selected
        local sel_count=0
        for s in "${tool_selected[@]}"; do
            [ "$s" = "yes" ] && [ "${tool_installed[0]}" != "" ] && sel_count=$((sel_count + 1))
        done

        tui_box_line "  ${BOLD}[$sel_count selected]${NC}$(tui_center "Press [Enter] to update" $((width - 40)))"

        tui_box_footer "$width"

        # Read key
        local key=""
        read -rsn1 key 2>/dev/null || true

        case "$key" in
            j|$'\x1b')
                # Down arrow or j: check for escape sequence
                local key2=""
                read -rsn1 -t 0.01 key2 2>/dev/null || true
                if [ "$key2" = "[" ]; then
                    read -rsn1 -t 0.01 key2 2>/dev/null || true
                    if [ "$key2" = "A" ]; then
                        # Up arrow
                        cursor=$((cursor - 1))
                        [ "$cursor" -lt 0 ] && cursor=$((tool_count - 1))
                    elif [ "$key2" = "B" ]; then
                        # Down arrow
                        cursor=$((cursor + 1))
                        [ "$cursor" -ge "$tool_count" ] && cursor=0
                    fi
                elif [ "$key" = "j" ]; then
                    cursor=$((cursor + 1))
                    [ "$cursor" -ge "$tool_count" ] && cursor=0
                fi
                ;;
            k)
                cursor=$((cursor - 1))
                [ "$cursor" -lt 0 ] && cursor=$((tool_count - 1))
                ;;
            ' ')
                # Toggle selection (only for installed tools)
                if [ "${tool_installed[$cursor]}" = "yes" ]; then
                    if [ "${tool_selected[$cursor]}" = "yes" ]; then
                        tool_selected[$cursor]="no"
                    else
                        tool_selected[$cursor]="yes"
                    fi
                fi
                ;;
            a)
                # Toggle all
                local all_selected="yes"
                for s in "${tool_selected[@]}"; do
                    [ "$s" = "no" ] && all_selected="no" && break
                done
                i=0
                while [ "$i" -lt "$tool_count" ]; do
                    if [ "${tool_installed[$i]}" = "yes" ]; then
                        if [ "$all_selected" = "yes" ]; then
                            tool_selected[$i]="no"
                        else
                            tool_selected[$i]="yes"
                        fi
                    fi
                    i=$((i + 1))
                done
                ;;
            q)
                tui_restore
                trap - EXIT INT TERM
                return 0
                ;;
            '')
                # Enter: execute selected updates
                tui_restore
                trap - EXIT INT TERM
                tui_clear_screen

                # Build list of selected tool names
                local -a targets=()
                i=0
                while [ "$i" -lt "$tool_count" ]; do
                    if [ "${tool_selected[$i]}" = "yes" ] && [ "${tool_installed[$i]}" = "yes" ]; then
                        targets+=("${tool_names[$i]}")
                    fi
                    i=$((i + 1))
                done

                if [ ${#targets[@]} -eq 0 ]; then
                    print_info "No tools selected for update"
                    return 0
                fi

                # Execute updates with summary
                update_specific_with_summary "${targets[@]}"
                return 0
                ;;
        esac
    done
}

# ── Key input helper ──────────────────────────────────────────────

# Read a single keypress (handles escape sequences for arrow keys)
# Sets KEY_NAME variable: up, down, left, right, space, enter, q, a, or the literal char
read_key() {
    local key=""
    read -rsn1 key 2>/dev/null || true

    KEY_NAME=""

    case "$key" in
        $'\x1b')
            local seq1="" seq2=""
            read -rsn1 -t 0.05 seq1 2>/dev/null || true
            read -rsn1 -t 0.05 seq2 2>/dev/null || true
            if [ "$seq1" = "[" ]; then
                case "$seq2" in
                    A) KEY_NAME="up" ;;
                    B) KEY_NAME="down" ;;
                    C) KEY_NAME="right" ;;
                    D) KEY_NAME="left" ;;
                    *) KEY_NAME="escape" ;;
                esac
            else
                KEY_NAME="escape"
            fi
            ;;
        '')
            KEY_NAME="enter"
            ;;
        ' ')
            KEY_NAME="space"
            ;;
        *)
            KEY_NAME="$key"
            ;;
    esac
}
