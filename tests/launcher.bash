#!/usr/bin/env bash

# Exercise mount selection and argument boundaries without building or running a
# container. The stub records argv as NUL-delimited data, including unusual paths.
set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp --directory)"
trap 'rm -rf -- "${TEST_ROOT}"' EXIT
mkdir -p "${TEST_ROOT}/bin" "${TEST_ROOT}/first" "${TEST_ROOT}/second" "${TEST_ROOT}/third" \
  "${TEST_ROOT}/comma, and \"quote\"" "${TEST_ROOT}/config/codex-sandbox"
cat >"${TEST_ROOT}/bin/podman" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  image) exit "${SANDBOX_TEST_IMAGE_MISSING:-0}" ;;
  build) printf '%s\0' "$@" >"${SANDBOX_TEST_BUILD}" ;;
  run) printf '%s\0' "$@" >"${SANDBOX_TEST_RUN}" ;;
  *) exit 99 ;;
esac
STUB
chmod +x "${TEST_ROOT}/bin/podman"
ln --symbolic "${PROJECT_ROOT}/run.bash" "${TEST_ROOT}/bin/codex-sandbox"
export PATH="${TEST_ROOT}/bin:${PATH}"
export SANDBOX_TEST_RUN="${TEST_ROOT}/run-args"
export SANDBOX_TEST_BUILD="${TEST_ROOT}/build-args"
export XDG_CONFIG_HOME="${TEST_ROOT}/config"
unset CODEX_SANDBOX_CONFIG
ARGUMENTS=()
CHECKS=0

fail() { echo "FAIL: $*" >&2; exit 1; }

write_config() {
  python3 - "$@" <<'PY'
import sys
import yaml

print("# Named host directories mounted under /workspace")
yaml.safe_dump({"workspace": dict(zip(sys.argv[1::2], sys.argv[2::2]))},
               sys.stdout, sort_keys=False)
PY
}

launch() {
  : >"${SANDBOX_TEST_RUN}"
  "${PROJECT_ROOT}/run.bash" "$@"
  mapfile -d '' -t ARGUMENTS <"${SANDBOX_TEST_RUN}"
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

suffix() {
  local index=0 start=$((${#ARGUMENTS[@]} - $#)) expected
  for expected in "$@"; do
    [[ "${ARGUMENTS[start + index]}" == "${expected}" ]] || fail "unexpected command suffix"
    index=$((index + 1))
  done
}

reject() {
  local status=0
  : >"${SANDBOX_TEST_RUN}"
  "${PROJECT_ROOT}/run.bash" "$@" >"${TEST_ROOT}/error" 2>&1 || status=$?
  [[ "${status}" == 2 ]] || fail "expected status 2, got ${status}"
  [[ ! -s "${SANDBOX_TEST_RUN}" ]] || fail "invalid input reached Podman run"
  CHECKS=$((CHECKS + 1))
}

launch "${TEST_ROOT}/first" "${TEST_ROOT}/second"
pair --workdir /workspace/first
pair --add-dir /workspace/second
pair --mount "type=bind,\"source=${TEST_ROOT}/first\",\"target=/workspace/first\",relabel=private"
pair --mount "type=bind,\"source=${TEST_ROOT}/second\",\"target=/workspace/second\",relabel=private"
contains --read-only || fail 'missing read-only root'
contains --cap-drop || fail 'missing capability restriction'
pair --cap-drop ALL
contains --userns=keep-id || fail 'missing rootless user namespace'
pair --security-opt no-new-privileges=true
pair --pids-limit 512
pair --mount type=volume,source=codex-sandbox-home,target=/home/codex
pair --tmpfs /workspace:rw,nosuid,nodev,size=1g,mode=1777
suffix codex --no-daemon --add-dir /workspace/second

launch "${TEST_ROOT}/second" "${TEST_ROOT}/first"
pair --workdir /workspace/second
pair --add-dir /workspace/first

launch "${TEST_ROOT}/first"
pair --workdir /workspace/first
if contains --add-dir; then fail 'single project has extra writable roots'; fi

for flag in -e --empty-workspace; do
  launch "${flag}"
  pair --workdir /workspace
  if contains --add-dir; then fail 'empty launch has extra writable roots'; fi
  for argument in "${ARGUMENTS[@]}"; do
    [[ "${argument}" != type=bind,* ]] || fail 'empty launch has a host project mount'
  done
done

# shellcheck disable=SC2016 # Verify that forwarded arguments are never evaluated.
literal_prompt='literal $(not-a-command)'
launch "${TEST_ROOT}/comma, and \"quote\"" -- --model example "${literal_prompt}" $'two\nlines'
pair --workdir '/workspace/comma, and "quote"'
pair --mount "type=bind,\"source=${TEST_ROOT}/comma, and \"\"quote\"\"\",\"target=/workspace/comma, and \"\"quote\"\"\",relabel=private"
suffix codex --no-daemon \
  --model example "${literal_prompt}" $'two\nlines'

reject
reject -e "${TEST_ROOT}/first"
reject --build "${TEST_ROOT}/first"
reject --unknown
reject "${TEST_ROOT}/nonexistent"
mkdir -p "${TEST_ROOT}/a/same" "${TEST_ROOT}/b/same"
reject "${TEST_ROOT}/a/same" "${TEST_ROOT}/b/same"

# Direct launches also work without a default config or explicit project.
launch -- --model example
pair --workdir /workspace
suffix codex --no-daemon --model example
for argument in "${ARGUMENTS[@]}"; do
  [[ "${argument}" != type=bind,* ]] || fail 'unconfigured launch has a host project mount'
done
launch --
pair --workdir /workspace
suffix codex --no-daemon

# A default configuration uses stable names and anchors relative paths at the file.
write_config api "${TEST_ROOT}/first" ui ../../second docs "${TEST_ROOT}/third" \
  >"${XDG_CONFIG_HOME}/codex-sandbox/config.yaml"
launch
pair --workdir /workspace
pair --mount "type=bind,\"source=${TEST_ROOT}/first\",\"target=/workspace/api\",relabel=private"
pair --mount "type=bind,\"source=${TEST_ROOT}/second\",\"target=/workspace/ui\",relabel=private"
suffix /usr/local/bin/codex-sandbox-menu api ui docs --

# -- bypasses the menu even with no directories or forwarded arguments.
for direct_case in options resume named prompt empty; do
  case "${direct_case}" in
    options) forwarded=(--model example) ;;
    resume) forwarded=(resume --all) ;;
    named) forwarded=(resume 'Conversation name') ;;
    prompt) forwarded=("${literal_prompt}" $'two\nlines') ;;
    empty) forwarded=() ;;
  esac
  launch -- "${forwarded[@]}"
  pair --workdir /workspace
  for registration in api:first ui:second docs:third; do
    pair --mount "type=bind,\"source=${TEST_ROOT}/${registration#*:}\",\"target=/workspace/${registration%%:*}\",relabel=private"
  done
  if contains --add-dir || contains --cd; then fail 'neutral launch forced conversation scope'; fi
  suffix codex --no-daemon "${forwarded[@]}"
done

launch "${TEST_ROOT}/first" -- resume --all
pair --workdir /workspace/api
pair --mount "type=bind,\"source=${TEST_ROOT}/second\",\"target=/workspace/ui\",relabel=private"
suffix codex --no-daemon resume --all

# A primary path chooses the conversation root; it never removes registry mounts.
launch "${TEST_ROOT}/first"
pair --workdir /workspace/api
pair --mount "type=bind,\"source=${TEST_ROOT}/first\",\"target=/workspace/api\",relabel=private"
pair --mount "type=bind,\"source=${TEST_ROOT}/second\",\"target=/workspace/ui\",relabel=private"
pair --mount "type=bind,\"source=${TEST_ROOT}/third\",\"target=/workspace/docs\",relabel=private"
if contains --add-dir; then fail 'mounted projects were automatically made writable'; fi
if contains /usr/local/bin/codex-sandbox-menu; then fail 'explicit project opened a menu'; fi
if contains "type=bind,\"source=${TEST_ROOT}/first\",\"target=/workspace/first\",relabel=private"; then
  fail 'registered primary was mounted under a second name'
fi

ln --symbolic "${TEST_ROOT}/first" "${TEST_ROOT}/alias"
launch "${TEST_ROOT}/alias" "${TEST_ROOT}/second"
pair --workdir /workspace/api
pair --add-dir /workspace/ui
pair --mount "type=bind,\"source=${TEST_ROOT}/third\",\"target=/workspace/docs\",relabel=private"
if contains /workspace/docs; then fail 'unselected registry project became writable'; fi

launch "${TEST_ROOT}/second" "${TEST_ROOT}/first"
pair --workdir /workspace/ui
pair --add-dir /workspace/api

launch "${TEST_ROOT}/comma, and \"quote\""
pair --workdir '/workspace/comma, and "quote"'
pair --mount "type=bind,\"source=${TEST_ROOT}/first\",\"target=/workspace/api\",relabel=private"
pair --mount "type=bind,\"source=${TEST_ROOT}/second\",\"target=/workspace/ui\",relabel=private"

# An explicit path cannot mask a different registered project with the same name.
mkdir -p "${TEST_ROOT}/api"
reject "${TEST_ROOT}/api"

export CODEX_SANDBOX_CONFIG="${TEST_ROOT}/override.yaml"
printf -v home_relative '%s/%s' '~' "$(realpath --relative-to="${HOME}" "${TEST_ROOT}/first")"
write_config only "${home_relative}" >"${CODEX_SANDBOX_CONFIG}"
launch
pair --mount "type=bind,\"source=${TEST_ROOT}/first\",\"target=/workspace/only\",relabel=private"
suffix /usr/local/bin/codex-sandbox-menu only --

# Quoted YAML paths preserve punctuation, Unicode, and newlines without evaluation.
unusual_path="${TEST_ROOT}/"$'é, "quote"\nline $(not-a-command)'
mkdir -p "${unusual_path}"
write_config unusual "${unusual_path}" >"${CODEX_SANDBOX_CONFIG}"
launch
escaped_path="${unusual_path//\"/\"\"}"
pair --mount "type=bind,\"source=${escaped_path}\",\"target=/workspace/unusual\",relabel=private"
suffix /usr/local/bin/codex-sandbox-menu unusual --

for invalid in '{}' 'workspace: []' 'workspace: {}' 'workspace: {../escape: /tmp}' \
  'workspace: {bad name: /tmp}' 'workspace: {x: 42}' \
  'workspace: {"bad\n": /tmp}' 'workspace: {x: ""}' \
  'workspace: {x: "a\u0000b"}' 'not-a-mapping' 'workspace: [' \
  'workspace: {1: /tmp}' 'workspace: {x: null}' 'workspace: {x: [/tmp]}' \
  'projects: {x: /tmp}' 'workspace: {x: /tmp, x: /run}' \
  $'workspace: {x: /tmp}\nworkspace: {y: /run}' \
  $'workspace: {x: /tmp}\n---\nworkspace: {y: /run}' \
  'workspace: {x: !!python/object/apply:os.getcwd []}'; do
  printf '%s\n' "${invalid}" >"${CODEX_SANDBOX_CONFIG}"
  reject
done
reject "${TEST_ROOT}/first"
reject -- resume --all
printf '%s\n' 'workspace: {missing: does-not-exist}' >"${CODEX_SANDBOX_CONFIG}"
reject
reject "${TEST_ROOT}/first"
write_config one "${TEST_ROOT}/first" two "${TEST_ROOT}/first" >"${CODEX_SANDBOX_CONFIG}"
reject

# Only empty launches bypass a broken or missing configuration.
printf '%s\n' 'not-a-mapping' >"${CODEX_SANDBOX_CONFIG}"
launch -e
pair --workdir /workspace
launch -e -- resume --all
pair --workdir /workspace
suffix codex --no-daemon resume --all
for argument in "${ARGUMENTS[@]}"; do
  [[ "${argument}" != type=bind,* ]] || fail 'empty direct launch has a host project mount'
done
export CODEX_SANDBOX_CONFIG="${TEST_ROOT}/missing.yaml"
reject "${TEST_ROOT}/first"
reject -- resume --all
launch -e
pair --workdir /workspace
"${TEST_ROOT}/bin/codex-sandbox" --help >"${TEST_ROOT}/help"
CHECKS=$((CHECKS + 1))

export CODEX_SANDBOX_CONFIG="${XDG_CONFIG_HOME}/codex-sandbox/config.yaml"
SANDBOX_TEST_IMAGE_MISSING=1 launch "${TEST_ROOT}/first"
mapfile -d '' -t ARGUMENTS <"${SANDBOX_TEST_BUILD}"
pair --tag codex-sandbox:local
suffix --file "${PROJECT_ROOT}/Containerfile" "${PROJECT_ROOT}"
"${PROJECT_ROOT}/run.bash" --build
CHECKS=$((CHECKS + 1))

printf 'Launcher checks passed (%s cases).\n' "${CHECKS}"
