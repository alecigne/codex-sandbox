#!/usr/bin/env bash

set -euo pipefail

IMAGE="codex-sandbox:local"
SANDBOX_HOME_VOLUME="codex-sandbox-home"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REBUILD=false
REBUILD_ONLY=false
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
  run.bash [--rebuild] [DIRECTORY ...] [-- CODEX_ARGUMENTS...]
  run.bash --rebuild-only

Start an interactive Codex CLI in a container. Each directory is mounted below
/workspace using its basename. At least one directory is required. Use
--rebuild-only to rebuild the image without launching Codex.

Examples:
  ~/src/codex-sandbox/run.bash --rebuild-only
  ~/src/codex-sandbox/run.bash ~/src/my-project
  ~/src/codex-sandbox/run.bash ~/src/frontend ~/src/backend
  ~/src/codex-sandbox/run.bash ~/src/my-project -- --model gpt-5.6-sol
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --rebuild)
      REBUILD=true
      shift
      ;;
    --rebuild-only)
      REBUILD_ONLY=true
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

build_image() {
  podman build --pull=newer --tag "${IMAGE}" --file "${SCRIPT_DIR}/Containerfile" "${SCRIPT_DIR}"
}

if [[ "${REBUILD_ONLY}" == true ]]; then
  if [[ "${REBUILD}" == true || ${#DIRECTORIES[@]} -ne 0 || ${#CODEX_ARGUMENTS[@]} -ne 0 ]]; then
    echo "--rebuild-only cannot be combined with --rebuild, directories, or Codex arguments." >&2
    exit 2
  fi

  build_image
  exit 0
fi

if [[ ${#DIRECTORIES[@]} -eq 0 ]]; then
  echo "At least one workspace directory must be specified." >&2
  echo "Example: $0 ~/src/my-project" >&2
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

  if [[ "${workspace_name}" == "AGENTS.md" ]]; then
    echo "Reserved workspace directory name: ${workspace_name}" >&2
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

# Rebuild explicitly or when no local sandbox image exists.
if [[ "${REBUILD}" == true ]] || ! podman image exists "${IMAGE}"; then
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
  --env CODEX_SANDBOX_INIT_WORKSPACE=1 \
  --workdir /workspace \
  "${IMAGE}" \
  codex --sandbox workspace-write --ask-for-approval on-request "${CODEX_ARGUMENTS[@]}"
