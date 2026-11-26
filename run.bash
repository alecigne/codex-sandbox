#!/usr/bin/env bash

set -euo pipefail

IMAGE="codex-sandbox:local"
SANDBOX_HOME_VOLUME="codex-sandbox-home"
# Read NUL-terminated paths so Bash preserves trailing newlines.
IFS= read -r -d '' SCRIPT_PATH < <(realpath --zero -- "${BASH_SOURCE[0]}")
IFS= read -r -d '' SCRIPT_DIR < <(dirname --zero -- "${SCRIPT_PATH}")
EMPTY_WORKSPACE=false
CONTAINER_TERM="${TERM:-xterm-256color}"
CONTAINER_COLORTERM="${COLORTERM:-truecolor}"
TIMEZONE_ARGUMENTS=()
DIRECTORIES=()
WORKSPACE_NAMES=()
RESOLVED_DIRECTORIES=()
SELECTED_NAMES=()
CODEX_ARGUMENTS=()

if [[ $# -eq 0 ]]; then
  CODEX_ARGUMENTS=(agents)
fi

if [[ "${CONTAINER_TERM}" == "xterm" ]]; then
  CONTAINER_TERM="xterm-256color"
fi

# Print launcher syntax and common examples.
usage() {
  cat <<'EOF'
Usage:
  run.bash --build
  run.bash
  run.bash -- [CODEX_ARGUMENTS...]
  run.bash DIRECTORY... [-- CODEX_ARGUMENTS...]
  run.bash --empty-workspace [-- CODEX_ARGUMENTS...]
  run.bash -e [-- CODEX_ARGUMENTS...]

Load the workspace mapping and optional timezone from the YAML configuration at
${XDG_CONFIG_HOME:-~/.config}/codex-sandbox/config.yaml when configured.
CODEX_SANDBOX_CONFIG selects another file. Reading the configuration requires
Python 3 and PyYAML on the host.
Set timezone to a name such as Europe/Paris. The host's timezone database
is used to validate the name.

With a configured workspace, run without arguments to open Codex's Command
Center. Explicit directories or -- start Codex directly. The first explicit
directory, or the first configured project if none is supplied, is the starting
directory. Other explicit directories are added as writable roots with
--add-dir. Everything after -- is passed to Codex.
All configured projects stay mounted. Registered paths reuse their configured
names; other paths are mounted below /workspace using their basenames.
Without a configuration file, direct launches mount only explicit directories.
Use --empty-workspace (or -e) to bypass the configuration and start in /workspace
without host projects.
Use --build to build the image without launching Codex.

Examples:
  ~/src/codex-sandbox/run.bash --build
  codex-sandbox
  ~/src/codex-sandbox/run.bash --empty-workspace
  codex-sandbox -e
  ~/src/codex-sandbox/run.bash ~/src/my-project
  ~/src/codex-sandbox/run.bash ~/src/frontend ~/src/backend
  ~/src/codex-sandbox/run.bash ~/src/my-project -- --model gpt-6.1-sol
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
    --empty-workspace|-e)
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
  echo "--empty-workspace (-e) cannot be combined with workspace directories." >&2
  exit 2
fi

# Add each host directory once. Explicit paths reuse a registered alias, while
# distinct directories must never compete for the same container mount point.
register_directory() {
  local directory="$1" workspace_name="${2-}" resolved_directory index existing_name
  [[ -d "${directory}" ]] || { echo "Directory does not exist: ${directory}" >&2; exit 2; }
  IFS= read -r -d '' resolved_directory < <(realpath --zero -- "${directory}")
  if [[ "${resolved_directory}" == "/" ]]; then
    echo "Cannot mount the host filesystem root." >&2
    exit 2
  fi
  for index in "${!RESOLVED_DIRECTORIES[@]}"; do
    if [[ "${resolved_directory}" == "${RESOLVED_DIRECTORIES[index]}" ]]; then
      if [[ -n "${workspace_name}" && "${workspace_name}" != "${WORKSPACE_NAMES[index]}" ]]; then
        echo "Host directory is registered under more than one name: ${directory}" >&2
        exit 2
      fi
      DIRECTORY_INDEX="${index}"
      return
    fi
  done
  if [[ -z "${workspace_name}" ]]; then
    workspace_name="${resolved_directory##*/}"
  fi
  for existing_name in "${WORKSPACE_NAMES[@]}"; do
    if [[ "${workspace_name}" == "${existing_name}" ]]; then
      echo "Duplicate workspace directory name: ${workspace_name}" >&2
      exit 2
    fi
  done
  DIRECTORY_INDEX="${#RESOLVED_DIRECTORIES[@]}"
  RESOLVED_DIRECTORIES+=("${resolved_directory}")
  WORKSPACE_NAMES+=("${workspace_name}")
}

load_config() {
  local config_file="$1" config_base directory field_index
  local -a config_fields
  if [[ ! -f "${config_file}" || ! -r "${config_file}" ]]; then
    echo "Configuration file is missing or unreadable: ${config_file}" >&2
    printf 'Create a YAML file such as:\nworkspace:\n  my-project: ~/src/my-project\n' >&2
    echo "With no configuration, pass a host directory or use -e for an empty workspace." >&2
    exit 2
  fi
  if ! command -v python3 >/dev/null; then
    echo "Reading the configuration requires Python 3 and PyYAML on the host." >&2
    exit 2
  fi
  IFS= read -r -d '' config_file < <(realpath --zero -- "${config_file}")
  IFS= read -r -d '' config_base < <(dirname --zero -- "${config_file}")
  # Keep paths lossless across the Python/Bash boundary. Wait for the parser so
  # invalid configuration cannot silently become an empty set of mounts.
  mapfile -d '' -t config_fields < <(python3 - "${config_file}" <<'PY'
from pathlib import Path
import re
import sys

try:
    import yaml
except ImportError:
    sys.exit("Reading the configuration requires PyYAML on the host (e.g. python3-yaml).")


class ConfigLoader(yaml.SafeLoader):
    def construct_mapping(self, node, deep=False):
        self.flatten_mapping(node)
        mapping = {}
        for key_node, value_node in node.value:
            key = self.construct_object(key_node, deep=deep)
            if not isinstance(key, str):
                raise ValueError("configuration keys must be strings")
            if key in mapping:
                raise ValueError(f"duplicate configuration key: {key!r}")
            mapping[key] = self.construct_object(value_node, deep=deep)
        return mapping


try:
    with open(sys.argv[1], encoding="utf-8") as source:
        config = yaml.load(source, Loader=ConfigLoader)
    workspace = config.get("workspace") if isinstance(config, dict) else None
    if not isinstance(workspace, dict) or not workspace:
        raise ValueError("expected a nonempty workspace mapping of names to paths")
    timezone = config.get("timezone", "")
    if "timezone" in config:
        if not isinstance(timezone, str) or not re.fullmatch(
            r"[A-Za-z0-9_+-]+(?:/[A-Za-z0-9_+-]+)*", timezone
        ):
            raise ValueError("timezone must be an IANA name such as Europe/Paris")
        try:
            with (Path("/usr/share/zoneinfo") / timezone).open("rb") as zone:
                if zone.read(4) != b"TZif":
                    raise ValueError(f"invalid timezone: {timezone!r}")
        except OSError as error:
            raise ValueError(f"timezone {timezone!r} unavailable in host timezone data") from error
    for name, path in workspace.items():
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", name):
            raise ValueError(f"invalid workspace name: {name!r}")
        if not isinstance(path, str) or not path or "\0" in path:
            raise ValueError(f"expected a nonempty path string for {name!r}")
    fields = [timezone, *(field for item in workspace.items() for field in item)]
    sys.stdout.buffer.write(("\0".join(fields) + "\0").encode("utf-8"))
except (OSError, UnicodeError, yaml.YAMLError, ValueError) as error:
    sys.exit(f"Invalid configuration {sys.argv[1]}: {error}")
PY
  )
  if ! wait "$!"; then
    exit 2
  fi
  if [[ -n "${config_fields[0]}" ]]; then
    TIMEZONE_ARGUMENTS=(--env "TZ=${config_fields[0]}")
  fi
  for ((field_index = 1; field_index < ${#config_fields[@]}; field_index += 2)); do
    directory="${config_fields[field_index + 1]}"
    case "${directory}" in
      '~') directory="${HOME}" ;;
      \~/*) directory="${HOME}/${directory:2}" ;;
      /*) ;;
      *) directory="${config_base}/${directory}" ;;
    esac
    register_directory "${directory}" "${config_fields[field_index]}"
  done
}

if [[ "${EMPTY_WORKSPACE}" == false ]]; then
  config_file="${CODEX_SANDBOX_CONFIG:-${XDG_CONFIG_HOME:-${HOME}/.config}/codex-sandbox/config.yaml}"
  if [[ -e "${config_file}" || -L "${config_file}" || -n "${CODEX_SANDBOX_CONFIG:-}" || ${#DIRECTORIES[@]} -eq 0 ]]; then
    load_config "${config_file}"
  fi
fi

for directory in "${DIRECTORIES[@]}"; do
  register_directory "${directory}"
  SELECTED_NAMES+=("${WORKSPACE_NAMES[DIRECTORY_INDEX]}")
done

CONTAINER_WORKDIR=/workspace
ADDITIONAL_DIRECTORY_ARGUMENTS=()
if [[ ${#SELECTED_NAMES[@]} -gt 0 ]]; then
  CONTAINER_WORKDIR="/workspace/${SELECTED_NAMES[0]}"
  for workspace_name in "${SELECTED_NAMES[@]:1}"; do
    if [[ "/workspace/${workspace_name}" != "${CONTAINER_WORKDIR}" ]]; then
      ADDITIONAL_DIRECTORY_ARGUMENTS+=(--add-dir "/workspace/${workspace_name}")
    fi
  done
elif [[ ${#WORKSPACE_NAMES[@]} -gt 0 ]]; then
  CONTAINER_WORKDIR="/workspace/${WORKSPACE_NAMES[0]}"
fi

DIRECTORY_MOUNTS=()
for index in "${!RESOLVED_DIRECTORIES[@]}"; do
  # Podman parses --mount as CSV. Quote whole fields and double embedded quotes
  # so commas and quotes in directory names remain part of the paths.
  mount_source="${RESOLVED_DIRECTORIES[index]//\"/\"\"}"
  mount_target="/workspace/${WORKSPACE_NAMES[index]//\"/\"\"}"
  DIRECTORY_MOUNTS+=(
    --mount
    "type=bind,\"source=${mount_source}\",\"target=${mount_target}\",relabel=private"
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
  "${TIMEZONE_ARGUMENTS[@]}" \
  --read-only \
  --shm-size 1g \
  --tmpfs /tmp:rw,nosuid,nodev,size=1g \
  --tmpfs /run:rw,nosuid,nodev,size=64m \
  --tmpfs /workspace:rw,nosuid,nodev,size=1g,mode=1777 \
  --cap-drop ALL \
  --security-opt no-new-privileges=true \
  --pids-limit 512 \
  "${DIRECTORY_MOUNTS[@]}" \
  --mount "type=volume,source=${SANDBOX_HOME_VOLUME},target=/home/codex" \
  --workdir "${CONTAINER_WORKDIR}" \
  "${IMAGE}" \
  codex --no-daemon --ask-for-approval on-request \
  "${ADDITIONAL_DIRECTORY_ARGUMENTS[@]}" "${CODEX_ARGUMENTS[@]}"
