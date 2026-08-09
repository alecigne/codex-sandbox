#!/usr/bin/env bash

set -euo pipefail

IMAGE="codex-sandbox:local"
SANDBOX_HOME_VOLUME="codex-sandbox-home"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REBUILD=false
CONTAINER_TERM="${TERM:-xterm-256color}"
CONTAINER_COLORTERM="${COLORTERM:-truecolor}"

if [[ "${CONTAINER_TERM}" == "xterm" ]]; then
  CONTAINER_TERM="xterm-256color"
fi

usage() {
  cat <<'EOF'
Usage: run.bash [--rebuild] [PROJECT] [-- CODEX_ARGUMENTS...]

Start an interactive Codex CLI in a container. PROJECT defaults to the current
directory.

Examples:
  ~/src/codex-sandbox/run.bash
  ~/src/codex-sandbox/run.bash ~/src/my-project
  ~/src/codex-sandbox/run.bash ~/src/my-project -- --model gpt-5.4
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "${1:-}" == "--rebuild" ]]; then
  REBUILD=true
  shift
fi

if [[ $# -gt 0 && "$1" != "--" ]]; then
  PROJECT="$1"
  shift
else
  PROJECT="${PWD}"
fi

if [[ "${1:-}" == "--" ]]; then
  shift
fi

[[ -d "${PROJECT}" ]] || { echo "Project is not a directory: ${PROJECT}" >&2; exit 2; }
PROJECT="$(realpath -- "${PROJECT}")"

if [[ "${REBUILD}" == true ]] || ! podman image exists "${IMAGE}"; then
  podman build --tag "${IMAGE}" --file "${SCRIPT_DIR}/Containerfile" "${SCRIPT_DIR}"
fi

exec podman run --rm --interactive --tty \
  --hostname codex-sandbox \
  --userns=keep-id \
  --env "TERM=${CONTAINER_TERM}" \
  --env "COLORTERM=${CONTAINER_COLORTERM}" \
  --read-only \
  --tmpfs /tmp:rw,nosuid,nodev,size=1g \
  --tmpfs /run:rw,nosuid,nodev,size=64m \
  --cap-drop ALL \
  --security-opt no-new-privileges=true \
  --pids-limit 512 \
  --mount "type=bind,source=${PROJECT},target=/workspace,relabel=private" \
  --mount "type=volume,source=${SANDBOX_HOME_VOLUME},target=/home/node" \
  --workdir /workspace \
  "${IMAGE}" \
  codex --sandbox workspace-write --ask-for-approval on-request "$@"
