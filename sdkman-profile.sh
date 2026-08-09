# shellcheck shell=bash

if [ -n "${BASH_VERSION:-}" ] && [ -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]; then
  # BASH_ENV invokes this profile for Codex-generated Bash commands.
  # shellcheck disable=SC1091
  . "${SDKMAN_DIR}/bin/sdkman-init.sh"
fi
