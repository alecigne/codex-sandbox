#!/usr/bin/env bash

set -euo pipefail

SDKMAN_SEED=/opt/sdkman
SDKMAN_CONFIG="${SDKMAN_DIR}/etc/config"
HOME_TEMPLATE=/usr/local/share/codex-sandbox/home

# Refresh image-managed home files without removing runtime-owned state.
cp --archive --no-preserve=ownership --remove-destination \
  "${HOME_TEMPLATE}/." \
  "${HOME}/"

# Initialize SDKMAN once without replacing installed JDKs on later launches.
if [[ ! -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]]; then
  mkdir -p "${SDKMAN_DIR}"
  cp -a "${SDKMAN_SEED}/." "${SDKMAN_DIR}/"
fi

# Existing volumes may predate the image's disabled health-check setting.
if [[ -f "${SDKMAN_CONFIG}" ]]; then
  sed -i \
    's/^sdkman_healthcheck_enable=.*/sdkman_healthcheck_enable=false/' \
    "${SDKMAN_CONFIG}"
fi

exec "$@"
