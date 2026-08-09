FROM node:24-trixie-slim

ARG CODEX_VERSION=0.147.0
ARG SDKMAN_VERSION=5.23.0
ARG SDKMAN_NATIVE_VERSION=0.7.34
ARG SDKMAN_INSTALLER_SHA256=e9ea5bde2e8b2725e69f70ab2fd5b03839d571df31231a726677e0161c8a40c1

# Keep UID/GID 1000 while giving the base image account a project-specific name.
RUN groupmod --new-name codex node && usermod --login codex --home /home/codex --move-home node

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bubblewrap \
        ca-certificates \
        curl \
        elan \
        git \
        just \
        ripgrep \
        shellcheck \
        unzip \
        zip \
    && rm -rf /var/lib/apt/lists/* \
    && npm install --global "@openai/codex@${CODEX_VERSION}" \
    && npm cache clean --force \
    && mkdir -p /home/codex/.codex /home/codex/.sdkman /workspace \
    && chown -R codex:codex /home/codex /workspace

# Install a verified SDKMAN seed for new persistent home volumes.
RUN export SDKMAN_DIR=/opt/sdkman \
    && curl --fail --show-error --silent --location "https://get.sdkman.io?rcupdate=false" --output /tmp/install-sdkman.sh \
    && printf '%s  %s\n' "${SDKMAN_INSTALLER_SHA256}" /tmp/install-sdkman.sh | sha256sum --check --strict - \
    && grep --fixed-strings --line-regexp "export SDKMAN_VERSION=\"${SDKMAN_VERSION}\"" /tmp/install-sdkman.sh \
    && grep --fixed-strings --line-regexp "export SDKMAN_NATIVE_VERSION=\"${SDKMAN_NATIVE_VERSION}\"" /tmp/install-sdkman.sh \
    && bash /tmp/install-sdkman.sh \
    && rm /tmp/install-sdkman.sh \
    && sed -i 's/^sdkman_healthcheck_enable=.*/sdkman_healthcheck_enable=false/' /opt/sdkman/etc/config \
    && chown -R codex:codex /opt/sdkman

COPY sdkman-profile.sh /etc/profile.d/sdkman.sh
COPY container-entrypoint.bash /usr/local/bin/container-entrypoint

RUN chmod 0755 /usr/local/bin/container-entrypoint

ENV HOME=/home/codex \
    CODEX_HOME=/home/codex/.codex \
    ELAN_HOME=/home/codex/.elan \
    SDKMAN_DIR=/home/codex/.sdkman \
    BASH_ENV=/etc/profile.d/sdkman.sh

USER codex
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/container-entrypoint"]
