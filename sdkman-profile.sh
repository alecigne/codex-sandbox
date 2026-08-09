if [ -n "${BASH_VERSION:-}" ] && [ -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]; then
  # shellcheck disable=SC1091
  . "${SDKMAN_DIR}/bin/sdkman-init.sh"
fi
