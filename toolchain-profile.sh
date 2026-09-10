# shellcheck shell=bash

# /etc/profile resets PATH for login shells. Restore the image-managed
# toolchain paths, and do the same for non-interactive Bash through BASH_ENV.
for codex_toolchain_path in \
  "${HOME}/.local/bin" \
  "${GOPATH:-${HOME}/go}/bin" \
  /usr/local/go/bin
do
  case ":${PATH:-}:" in
    *":${codex_toolchain_path}:"*) ;;
    *) PATH="${codex_toolchain_path}${PATH:+:${PATH}}" ;;
  esac
done
unset codex_toolchain_path
export PATH

if [ -n "${BASH_VERSION:-}" ] && [ -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]; then
  # BASH_ENV invokes this profile for Codex-generated Bash commands.
  # shellcheck disable=SC1091
  . "${SDKMAN_DIR}/bin/sdkman-init.sh"
fi
