#!/usr/bin/env bash

set -euo pipefail

SDKMAN_SEED=/opt/sdkman
SDKMAN_CONFIG="${SDKMAN_DIR}/etc/config"
GLOBAL_AGENTS_FILE=/usr/local/share/codex-sandbox/AGENTS.md

# Keep the global guidance image-managed while Codex state persists in a volume.
mkdir -p "${CODEX_HOME}"
ln --symbolic --force --no-target-directory \
  "${GLOBAL_AGENTS_FILE}" \
  "${CODEX_HOME}/AGENTS.md"

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
