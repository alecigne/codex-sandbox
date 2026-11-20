#!/usr/bin/env bash

# Exercise the real menu launch functions with deterministic choices and a Codex
# executable stub. Map cwd to fixtures so no /workspace mounts or TTY are needed.
set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp --directory)"
trap 'rm -rf -- "${TEST_ROOT}"' EXIT
mkdir -p "${TEST_ROOT}/first" "${TEST_ROOT}/second" "${TEST_ROOT}/third" "${TEST_ROOT}/bin"
cat >"${TEST_ROOT}/bin/codex" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\0' "$@" >"${SANDBOX_MENU_TEST_ROOT}/codex-args"
printf '%s' "${PWD}" >"${SANDBOX_MENU_TEST_ROOT}/codex-cwd"
exit "${MENU_CODEX_STATUS}"
STUB
chmod +x "${TEST_ROOT}/bin/codex"
export PATH="${TEST_ROOT}/bin:${PATH}"
export SANDBOX_MENU_TEST_ROOT="${TEST_ROOT}"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../image/usr/local/bin/codex-sandbox-menu
source "${PROJECT_ROOT}/image/usr/local/bin/codex-sandbox-menu"

PROJECTS=(first second third)
PROJECT_LABELS=()
for project in "${PROJECTS[@]}"; do
  printf -v label '%-20s /workspace/%s' "${project}" "${project}"
  PROJECT_LABELS+=("${label}")
done
# shellcheck disable=SC2016 # This must be passed literally, never evaluated.
literal_option='example=$(not-a-command)'
CODEX_ARGUMENTS=(--model example --config "${literal_option}")
MENU_SELECTION=''
MENU_GUM_STATUS=0
export MENU_CODEX_STATUS=0
ARGUMENTS=()
CHECKS=0

fail() { echo "FAIL: $*" >&2; exit 1; }

cd() {
  [[ "$1" == -- ]] || fail 'missing cwd argument boundary'
  case "$2" in
    /workspace) builtin cd -- "${TEST_ROOT}" ;;
    /workspace/*) builtin cd -- "${TEST_ROOT}/${2#/workspace/}" ;;
    *) fail "unexpected conversation directory: $2" ;;
  esac
}

# Isolate exec from the test runner and fail if control returns to the menu.
launch() (
  "$@"
  fail 'Codex returned to the menu instead of replacing it'
)

gum() {
  printf '%s\0' "$@" >"${TEST_ROOT}/gum-args"
  printf '%s' "${MENU_SELECTION}"
  return "${MENU_GUM_STATUS}"
}

capture() {
  mapfile -d '' -t ARGUMENTS <"${TEST_ROOT}/codex-args"
  CHECKS=$((CHECKS + 1))
}

contains() {
  local expected="$1" argument
  for argument in "${ARGUMENTS[@]}"; do
    [[ "${argument}" != "${expected}" ]] || return 0
  done
  return 1
}

pair() {
  local index
  for ((index = 0; index + 1 < ${#ARGUMENTS[@]}; index++)); do
    if [[ "${ARGUMENTS[index]}" == "$1" && "${ARGUMENTS[index + 1]}" == "$2" ]]; then
      return 0
    fi
  done
  fail "missing argument pair: $1 $2"
}

launch run_codex /workspace/first new
capture
if contains --sandbox || contains --ask-for-approval || contains 'default_permissions=":workspace"'; then
  fail 'new conversation forced a permission or approval policy'
fi
pair --cd /workspace/first
pair --config "${literal_option}"
contains --no-daemon || fail 'missing embedded server mode'
if contains --add-dir; then fail 'primary-only launch granted extra roots'; fi
[[ "$(<"${TEST_ROOT}/codex-cwd")" == "${TEST_ROOT}/first" ]] || fail 'wrong process cwd'

# An empty optional selection starts with only the primary project writable.
launch start_new_conversation first
capture
if contains --add-dir; then fail 'empty selection granted extra roots'; fi
mapfile -d '' -t ARGUMENTS <"${TEST_ROOT}/gum-args"
contains --no-limit || fail 'additional-project chooser is not multi-select'
if contains "${PROJECT_LABELS[0]}"; then fail 'chooser offered primary as an extra root'; fi

MENU_SELECTION="${PROJECT_LABELS[1]}"
launch start_new_conversation first
capture
pair --cd /workspace/first
pair --add-dir /workspace/second
if contains /workspace/third; then fail 'unselected project became writable'; fi

printf -v MENU_SELECTION '%s\n%s' "${PROJECT_LABELS[1]}" "${PROJECT_LABELS[2]}"
launch start_new_conversation first
capture
pair --add-dir /workspace/second
pair --add-dir /workspace/third

: >"${TEST_ROOT}/codex-args"
MENU_GUM_STATUS=1
start_new_conversation first
[[ ! -s "${TEST_ROOT}/codex-args" ]] || fail 'cancelling launched a conversation'
CHECKS=$((CHECKS + 1))
MENU_GUM_STATUS=0

MENU_SELECTION='/workspace/not-registered'
launch start_new_conversation first
capture
if contains --add-dir; then fail 'unrecognized selection granted an extra root'; fi

# Resume must not add every available mount or override a saved directory.
launch run_codex /workspace resume
capture
contains agents || fail 'Resume did not open the command center'
if contains --sandbox || contains --ask-for-approval || contains 'default_permissions=":workspace"'; then
  fail 'Resume forced a permission or approval policy'
fi
if contains --add-dir || contains --cd; then fail 'Resume forced conversation scope'; fi
[[ "$(<"${TEST_ROOT}/codex-cwd")" == "${TEST_ROOT}" ]] || fail 'Resume did not start neutrally'

# Both menu actions preserve normal, error, and interrupt exit statuses.
for mode in new resume; do
  for MENU_CODEX_STATUS in 0 42 130; do
    status=0
    launch run_codex /workspace/first "${mode}" || status=$?
    [[ "${status}" == "${MENU_CODEX_STATUS}" ]] || fail "${mode} changed Codex exit status to ${status}"
    CHECKS=$((CHECKS + 1))
  done
done
MENU_CODEX_STATUS=0

# With one registered project there is no optional-project screen.
PROJECTS=(first)
PROJECT_LABELS=("${PROJECT_LABELS[0]}")
: >"${TEST_ROOT}/gum-args"
launch start_new_conversation first
capture
[[ ! -s "${TEST_ROOT}/gum-args" ]] || fail 'single-project launch opened an extra chooser'

printf 'Workspace menu checks passed (%s cases).\n' "${CHECKS}"
