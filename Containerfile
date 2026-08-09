FROM node:24-bookworm-slim

ARG CODEX_VERSION=0.147.0
ARG SDKMAN_VERSION=5.23.0
ARG SDKMAN_NATIVE_VERSION=0.7.34
ARG SDKMAN_INSTALLER_SHA256=e9ea5bde2e8b2725e69f70ab2fd5b03839d571df31231a726677e0161c8a40c1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bubblewrap \
        ca-certificates \
        curl \
        git \
        unzip \
        zip \
    && rm -rf /var/lib/apt/lists/* \
    && npm install --global "@openai/codex@${CODEX_VERSION}" \
    && npm cache clean --force \
    && mkdir -p /home/node/.codex /home/node/.sdkman /workspace \
    && chown -R node:node /home/node /workspace

# Install a verified SDKMAN seed for new persistent home volumes.
RUN export SDKMAN_DIR=/opt/sdkman \
    && curl --fail --show-error --silent --location "https://get.sdkman.io?rcupdate=false" --output /tmp/install-sdkman.sh \
    && printf '%s  %s\n' "${SDKMAN_INSTALLER_SHA256}" /tmp/install-sdkman.sh | sha256sum --check --strict - \
    && grep --fixed-strings --line-regexp "export SDKMAN_VERSION=\"${SDKMAN_VERSION}\"" /tmp/install-sdkman.sh \
    && grep --fixed-strings --line-regexp "export SDKMAN_NATIVE_VERSION=\"${SDKMAN_NATIVE_VERSION}\"" /tmp/install-sdkman.sh \
    && bash /tmp/install-sdkman.sh \
    && rm /tmp/install-sdkman.sh \
    && sed -i 's/^sdkman_healthcheck_enable=.*/sdkman_healthcheck_enable=false/' /opt/sdkman/etc/config \
    && chown -R node:node /opt/sdkman

COPY sdkman-profile.sh /etc/profile.d/sdkman.sh
COPY container-entrypoint.bash /usr/local/bin/container-entrypoint

RUN chmod 0755 /usr/local/bin/container-entrypoint

ENV HOME=/home/node \
    CODEX_HOME=/home/node/.codex \
    SDKMAN_DIR=/home/node/.sdkman \
    BASH_ENV=/etc/profile.d/sdkman.sh

USER node
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/container-entrypoint"]
