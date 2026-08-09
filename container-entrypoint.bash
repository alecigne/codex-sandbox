#!/usr/bin/env bash

set -euo pipefail

SDKMAN_SEED=/opt/sdkman
SDKMAN_CONFIG="${SDKMAN_DIR}/etc/config"

# Explain the ephemeral multi-directory layout to Codex without merging the
# independently scoped instructions from its mounted projects.
if [[ "${CODEX_SANDBOX_INIT_WORKSPACE:-}" == "1" ]]; then
  cat > /workspace/AGENTS.md <<'EOF'
# Workspace guidance

You are working inside a disposable containerized environment. `/workspace` is
an ephemeral workspace root. Each immediate child is an independently selected
host working directory, and only changes made inside those children persist.

Before modifying files in a child directory, find and read the
`AGENTS.override.md` or `AGENTS.md` instructions that apply from that child root
through the target directory. Keep those instructions scoped to that child and
do not apply them to sibling directories.
EOF
  unset CODEX_SANDBOX_INIT_WORKSPACE
fi

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
