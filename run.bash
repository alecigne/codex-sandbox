#!/usr/bin/env bash

set -euo pipefail

IMAGE="codex-sandbox:local"
SANDBOX_HOME_VOLUME="codex-sandbox-home"
SCRIPT_PATH="$(realpath -- "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname -- "${SCRIPT_PATH}")"
EMPTY_WORKSPACE=false
CONTAINER_TERM="${TERM:-xterm-256color}"
CONTAINER_COLORTERM="${COLORTERM:-truecolor}"
DIRECTORIES=()
CODEX_ARGUMENTS=()

if [[ "${CONTAINER_TERM}" == "xterm" ]]; then
  CONTAINER_TERM="xterm-256color"
fi

# Print launcher syntax and common examples.
usage() {
  cat <<'EOF'
Usage:
  run.bash --build
  run.bash DIRECTORY... [-- CODEX_ARGUMENTS...]
  run.bash --empty-workspace [-- CODEX_ARGUMENTS...]

Start an interactive Codex CLI in a container. Each directory is mounted below
/workspace using its basename. Use --empty-workspace to mount no host working
directories; omitting both directories and that flag is an error. Use
--build to build the image without launching Codex.

Examples:
  ~/src/codex-sandbox/run.bash --build
  ~/src/codex-sandbox/run.bash --empty-workspace
  ~/src/codex-sandbox/run.bash ~/src/my-project
  ~/src/codex-sandbox/run.bash ~/src/frontend ~/src/backend
  ~/src/codex-sandbox/run.bash ~/src/my-project -- --model gpt-5.6-sol
EOF
}

build_image() {
  podman build --pull=newer --tag "${IMAGE}" --file "${SCRIPT_DIR}/Containerfile" "${SCRIPT_DIR}"
}

if [[ "${1-}" == "--build" ]]; then
  if [[ $# -ne 1 ]]; then
    echo "--build does not accept arguments." >&2
    exit 2
  fi

  build_image
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --build)
      echo "--build must be used without arguments." >&2
      exit 2
      ;;
    --empty-workspace)
      EMPTY_WORKSPACE=true
      shift
      ;;
    --)
      shift
      CODEX_ARGUMENTS=("$@")
      break
      ;;
    --*)
      echo "Unknown launcher option: $1" >&2
      echo "Place Codex arguments after --." >&2
      exit 2
      ;;
    *)
      DIRECTORIES+=("$1")
      shift
      ;;
  esac
done

if [[ "${EMPTY_WORKSPACE}" == true && ${#DIRECTORIES[@]} -ne 0 ]]; then
  echo "--empty-workspace cannot be combined with workspace directories." >&2
  exit 2
fi

if [[ "${EMPTY_WORKSPACE}" == false && ${#DIRECTORIES[@]} -eq 0 ]]; then
  echo "At least one workspace directory must be specified." >&2
  echo "Use --empty-workspace to launch without mounting a host working directory." >&2
  exit 2
fi

RESOLVED_DIRECTORIES=()
WORKSPACE_NAMES=()

for directory in "${DIRECTORIES[@]}"; do
  [[ -d "${directory}" ]] || { echo "Directory does not exist: ${directory}" >&2; exit 2; }

  resolved_directory="$(realpath -- "${directory}")"
  workspace_name="$(basename -- "${resolved_directory}")"

  if [[ "${workspace_name}" == "/" || "${workspace_name}" == "." || "${workspace_name}" == ".." ]]; then
    echo "Cannot derive a workspace name from directory: ${directory}" >&2
    exit 2
  fi

  for existing_name in "${WORKSPACE_NAMES[@]}"; do
    if [[ "${workspace_name}" == "${existing_name}" ]]; then
      echo "Duplicate workspace directory name: ${workspace_name}" >&2
      exit 2
    fi
  done

  RESOLVED_DIRECTORIES+=("${resolved_directory}")
  WORKSPACE_NAMES+=("${workspace_name}")
done

DIRECTORY_MOUNTS=()
for index in "${!RESOLVED_DIRECTORIES[@]}"; do
  DIRECTORY_MOUNTS+=(
    --mount
    "type=bind,source=${RESOLVED_DIRECTORIES[index]},target=/workspace/${WORKSPACE_NAMES[index]},relabel=private"
  )
done

# Build automatically when no local sandbox image exists.
if ! podman image exists "${IMAGE}"; then
  build_image
fi

# Mount only the selected directories and the container-owned persistent home.
exec podman run --rm --interactive --tty \
  --init \
  --hostname codex-sandbox \
  --userns=keep-id \
  --env "TERM=${CONTAINER_TERM}" \
  --env "COLORTERM=${CONTAINER_COLORTERM}" \
  --read-only \
  --tmpfs /tmp:rw,nosuid,nodev,size=1g \
  --tmpfs /run:rw,nosuid,nodev,size=64m \
  --tmpfs /workspace:rw,nosuid,nodev,size=1g,mode=1777 \
  --cap-drop ALL \
  --security-opt no-new-privileges=true \
  --pids-limit 512 \
  "${DIRECTORY_MOUNTS[@]}" \
  --mount "type=volume,source=${SANDBOX_HOME_VOLUME},target=/home/codex" \
  --workdir /workspace \
  "${IMAGE}" \
  codex --no-daemon --sandbox workspace-write --ask-for-approval on-request "${CODEX_ARGUMENTS[@]}"
