#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
export TMP_DIR

pass() {
    printf 'PASS: %s\n' "$1"
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local label="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$label"
    else
        printf '%s\n' "$haystack" >&2
        fail "$label"
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local label="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        printf '%s\n' "$haystack" >&2
        fail "$label"
    else
        pass "$label"
    fi
}

make_stub() {
    local path="$1"
    local content="$2"
    cat > "$path" <<EOF
#!/bin/bash
$content
EOF
    chmod +x "$path"
}

mkdir -p "$TMP_DIR/home/.local/bin" "$TMP_DIR/bin"
mkdir -p "$TMP_DIR/npm-global/bin"

make_stub "$TMP_DIR/home/.local/bin/codex" '
if [ "$1" = "--version" ] || [ "$1" = "-v" ]; then
  echo "codex-cli 0.114.0"
  exit 0
fi
echo "unexpected codex args: $*" >&2
exit 1
'

make_stub "$TMP_DIR/bin/npm" '
if [ "$1" = "prefix" ] && [ "$2" = "-g" ]; then
  echo "$TMP_DIR/npm-global"
  exit 0
fi
if [ "$1" = "list" ] && [ "$2" = "-g" ] && [ "$3" = "@openai/codex" ]; then
  echo "/opt/fake-npm/lib"
  echo "`-- @openai/codex@0.106.0"
  exit 0
fi
if [ "$1" = "view" ] && [ "$2" = "@openai/codex" ] && [ "$3" = "version" ]; then
  echo "0.115.0"
  exit 0
fi
if [ "$1" = "list" ] && [ "$2" = "-g" ] && [ "$3" = "cline" ]; then
  echo "/opt/fake-npm/lib"
  echo "`-- cline@1.4.0"
  exit 0
fi
if [ "$1" = "view" ] && [ "$2" = "cline" ] && [ "$3" = "version" ]; then
  echo "1.5.0"
  exit 0
fi
if [ "$1" = "list" ] && [ "$2" = "-g" ] && [ "$3" = "@qwen-code/qwen-code" ]; then
  echo "/opt/fake-npm/lib"
  echo "`-- @qwen-code/qwen-code@0.0.1"
  exit 0
fi
if [ "$1" = "view" ] && [ "$2" = "@qwen-code/qwen-code" ] && [ "$3" = "version" ]; then
  echo "0.0.3"
  exit 0
fi
echo "unexpected npm args: $*" >&2
exit 1
'

make_stub "$TMP_DIR/bin/brew" '
if [ "$1" = "--prefix" ]; then
  echo "/opt/homebrew"
  exit 0
fi
if [ "$1" = "list" ] && [ "$2" = "--cask" ] && [ "$3" = "codex" ]; then
  exit 0
fi
if [ "$1" = "list" ] && [ "$2" = "codex" ]; then
  exit 1
fi
if [ "$1" = "info" ] && [ "$2" = "codex" ] && [ "$3" = "--json" ]; then
  echo "[]"
  exit 0
fi
if [ "$1" = "info" ] && [ "$2" = "--cask" ] && [ "$3" = "codex" ] && [ "$4" = "--json=v2" ]; then
  echo "{\"casks\":[{\"version\":\"0.106.0\"}]}"
  exit 0
fi
echo "unexpected brew args: $*" >&2
exit 1
'

make_stub "$TMP_DIR/bin/pipx" '
if [ "$1" = "list" ]; then
  echo "package kimi-cli 0.6.0"
  exit 0
fi
if [ "$1" = "install" ] && [ "$2" = "kimi-cli" ]; then
  echo "installing kimi-cli"
  exit 0
fi
echo "unexpected pipx args: $*" >&2
exit 1
'

make_stub "$TMP_DIR/bin/uv" '
if [ "$1" = "tool" ] && [ "$2" = "list" ]; then
  echo "kimi-cli 0.6.0"
  exit 0
fi
if [ "$1" = "tool" ] && [ "$2" = "install" ] && [ "$3" = "kimi-cli" ]; then
  echo "installing kimi-cli"
  exit 0
fi
echo "unexpected uv args: $*" >&2
exit 1
'

make_stub "$TMP_DIR/bin/curl" '
if [[ "$*" == *"api.github.com/repos/volcanicll/kitup/releases/latest"* ]]; then
  echo "{\"tag_name\":\"v0.0.12\"}"
  exit 0
fi
if [[ "$*" == *"api.github.com/repos/openai/codex/releases/latest"* ]]; then
  echo "{\"tag_name\":\"rust-v0.114.0\"}"
  exit 0
fi
if [[ "$*" == *"api.github.com/repos/QwenLM/qwen-code/releases/latest"* ]]; then
  echo "{\"tag_name\":\"v0.0.1\"}"
  exit 0
fi
if [[ "$*" == *"pypi.org/pypi/kimi-cli/json"* ]]; then
  echo "{\"info\":{\"version\":\"0.6.0\"}}"
  exit 0
fi
echo "unexpected curl args: $*" >&2
exit 1
'

make_stub "$TMP_DIR/bin/jq" '
input=$(cat)
if [[ "$*" == *".tag_name"* ]]; then
  echo "$input" | sed -n "s/.*\"tag_name\":\"\\([^\"]*\\)\".*/\\1/p"
  exit 0
fi
if [[ "$*" == *".info.version"* ]]; then
  echo "$input" | sed -n "s/.*\"version\":\"\\([^\"]*\\)\".*/\\1/p"
  exit 0
fi
if [[ "$*" == *".casks[0].version"* ]]; then
  echo "$input" | sed -n "s/.*\"version\":\"\\([^\"]*\\)\".*/\\1/p"
  exit 0
fi
if [[ "$*" == *".[0].versions.stable"* ]]; then
  echo "$input" | sed -n "s/.*\"stable\":\"\\([^\"]*\\)\".*/\\1/p"
  exit 0
fi
exit 1
'

TEST_PATH="$TMP_DIR/home/.local/bin:$TMP_DIR/bin:/bin:/usr/bin"

PATH="$TEST_PATH" HOME="$TMP_DIR/home" bash "$ROOT_DIR/kitup.sh" -a -n > "$TMP_DIR/path-priority.out"
path_priority_output="$(cat "$TMP_DIR/path-priority.out")"
assert_contains "$path_priority_output" "codex is already up to date (0.114.0)" "PATH priority prefers standalone binary over npm/brew installs"
assert_not_contains "$path_priority_output" "Updating codex from 0.114.0" "No false update for current standalone binary"
assert_contains "$path_priority_output" "A newer kitup version is available: 0.0.12 (current: 0.0.11)" "kitup checks its own version while being used"
assert_contains "$path_priority_output" "Upgrade with: curl -fsSL https://raw.githubusercontent.com/volcanicll/kitup/main/packages/cli/install.sh | bash" "kitup shows a Unix self-update command"

mkdir -p "$TMP_DIR/restore-home/.config/kitup" "$TMP_DIR/restore-src"
printf 'restored-ok\n' > "$TMP_DIR/restore-src/sample.txt"
printf '%s\n' "$TMP_DIR/restore-src" > "$TMP_DIR/restore-home/.config/kitup/last_backup"
HOME="$TMP_DIR/restore-home" bash "$ROOT_DIR/kitup.sh" --restore > "$TMP_DIR/restore.out"
restore_output="$(cat "$TMP_DIR/restore.out")"
restored_contents="$(cat "$TMP_DIR/restore-home/sample.txt")"
assert_contains "$restore_output" "Configuration restored" "Restore uses ~/.config/kitup/last_backup"
if [ "$restored_contents" = "restored-ok" ]; then
    pass "Restore copies backup contents into HOME"
else
    fail "Restore copies backup contents into HOME"
fi

entry_output="$(KITUP_SKIP_SELF_UPDATE_CHECK=1 PATH="$TEST_PATH" HOME="$TMP_DIR/home" bash "$ROOT_DIR/kitup" --version)"
assert_contains "$entry_output" "kitup v0.0.11" "Unified entrypoint dispatches to shell implementation on Unix"

make_stub "$TMP_DIR/npm-global/bin/cline" '
if [ "$1" = "--version" ] || [ "$1" = "-v" ]; then
  echo "cline 1.4.0"
  exit 0
fi
exit 1
'
PATH="$TMP_DIR/npm-global/bin:$TEST_PATH" HOME="$TMP_DIR/home" KITUP_SKIP_SELF_UPDATE_CHECK=1 bash "$ROOT_DIR/kitup.sh" cline -n > "$TMP_DIR/cline.out"
cline_output="$(cat "$TMP_DIR/cline.out")"
assert_contains "$cline_output" "Updating cline from 1.4.0 to 1.5.0..." "Cline uses npm latest version detection"

PATH="$TEST_PATH" HOME="$TMP_DIR/home" KITUP_SKIP_SELF_UPDATE_CHECK=1 bash "$ROOT_DIR/kitup.sh" kimi --install -n > "$TMP_DIR/kimi.out"
kimi_output="$(cat "$TMP_DIR/kimi.out")"
assert_contains "$kimi_output" "[DRY RUN] Would install kimi" "Kimi supports dry-run install"

make_stub "$TMP_DIR/home/.local/bin/qwen" '
if [ "$1" = "--version" ] || [ "$1" = "-v" ]; then
  echo "qwen 0.0.1"
  exit 0
fi
exit 1
'
PATH="$TEST_PATH" HOME="$TMP_DIR/home" KITUP_SKIP_SELF_UPDATE_CHECK=1 bash "$ROOT_DIR/kitup.sh" qwen -n > "$TMP_DIR/qwen.out"
qwen_output="$(cat "$TMP_DIR/qwen.out")"
assert_contains "$qwen_output" "qwen is already up to date (0.0.1)" "Qwen standalone checks GitHub release version first"
assert_not_contains "$qwen_output" "Updating qwen from 0.0.1 to 0.0.3" "Qwen standalone does not fall back to npm version when GitHub matches"

printf 'All regression tests passed.\n'
