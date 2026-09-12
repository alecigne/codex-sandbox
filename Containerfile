FROM node:24-trixie-slim

ARG CODEX_VERSION=0.153.3
ARG AST_GREP_VERSION=0.45.0
ARG UV_VERSION=0.12.5
ARG UV_INSTALLER_SHA256=504511fbbbd811aeaba6738abc79408956b6c7da0ca35437b3dcc24a41efc111
ARG GO_VERSION=1.27.1
ARG GO_LINUX_AMD64_SHA256=63d339f0da5ab53635a56f2490a7984dfe12dfcff22ad749f63edaf590168445
ARG GO_LINUX_ARM64_SHA256=3450b45a3f9ee8568792736a5c5e70a1f2e9b36c35a8f74958c03e51d7d92bec
ARG TYPST_VERSION=0.15.1
ARG TYPST_LINUX_AMD64_SHA256=a6d077d0a95eed5a2eba715b2dae06be954f624ccbf85758a03f389ded33118c
ARG TYPST_LINUX_ARM64_SHA256=5aa8d74a3d906e60ea12a66ac2f37f8eef1b14cbad7182a745e393a10c23dcee
ARG SDKMAN_VERSION=5.23.0
ARG SDKMAN_NATIVE_VERSION=0.7.34
ARG SDKMAN_INSTALLER_SHA256=e9ea5bde2e8b2725e69f70ab2fd5b03839d571df31231a726677e0161c8a40c1

# Keep UID/GID 1000 while giving the base image account a project-specific name.
RUN groupmod --new-name codex node && usermod --login codex --home /home/codex --move-home node

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        elan \
        git \
        just \
        jq \
        pandoc \
        ripgrep \
        shellcheck \
        unzip \
        xz-utils \
        zip \
    && rm -rf /var/lib/apt/lists/* \
    && npm install --global \
        "@ast-grep/cli@${AST_GREP_VERSION}" \
        "@openai/codex@${CODEX_VERSION}" \
    && npm cache clean --force \
    && mkdir -p /home/codex/.codex /home/codex/.sdkman /workspace \
    && chown -R codex:codex /home/codex /workspace

# Install uv dynamically for the build architecture from a verified installer.
RUN curl --fail --show-error --silent --location "https://astral.sh/uv/${UV_VERSION}/install.sh" --output /tmp/install-uv.sh \
    && printf '%s  %s\n' "${UV_INSTALLER_SHA256}" /tmp/install-uv.sh | sha256sum --check --strict - \
    && grep --fixed-strings --line-regexp "APP_VERSION=\"${UV_VERSION}\"" /tmp/install-uv.sh \
    && UV_UNMANAGED_INSTALL=/usr/local/bin sh /tmp/install-uv.sh \
    && rm /tmp/install-uv.sh \
    && uv --version

# Install the official Go toolchain for the build architecture.
RUN architecture="$(dpkg --print-architecture)" \
    && case "${architecture}" in \
        amd64) go_sha256="${GO_LINUX_AMD64_SHA256}" ;; \
        arm64) go_sha256="${GO_LINUX_ARM64_SHA256}" ;; \
        *) echo "Unsupported Go architecture: ${architecture}" >&2; exit 1 ;; \
    esac \
    && go_archive="go${GO_VERSION}.linux-${architecture}.tar.gz" \
    && curl --fail --show-error --silent --location \
        "https://go.dev/dl/${go_archive}" \
        --output "/tmp/${go_archive}" \
    && printf '%s  %s\n' "${go_sha256}" "/tmp/${go_archive}" | sha256sum --check --strict - \
    && tar --extract --gzip --file "/tmp/${go_archive}" --directory /usr/local \
    && rm "/tmp/${go_archive}" \
    && /usr/local/go/bin/go version

# Install the official Typst CLI for the build architecture.
RUN architecture="$(dpkg --print-architecture)" \
    && case "${architecture}" in \
        amd64) \
            typst_target="x86_64-unknown-linux-musl"; \
            typst_sha256="${TYPST_LINUX_AMD64_SHA256}" \
            ;; \
        arm64) \
            typst_target="aarch64-unknown-linux-musl"; \
            typst_sha256="${TYPST_LINUX_ARM64_SHA256}" \
            ;; \
        *) echo "Unsupported Typst architecture: ${architecture}" >&2; exit 1 ;; \
    esac \
    && typst_archive="typst-${typst_target}.tar.xz" \
    && curl --fail --show-error --silent --location \
        "https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/${typst_archive}" \
        --output "/tmp/${typst_archive}" \
    && printf '%s  %s\n' "${typst_sha256}" "/tmp/${typst_archive}" | sha256sum --check --strict - \
    && tar --extract --xz --file "/tmp/${typst_archive}" --directory /usr/local/bin \
        --strip-components=1 "typst-${typst_target}/typst" \
    && rm "/tmp/${typst_archive}" \
    && typst --version

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

COPY toolchain-profile.sh /etc/profile.d/codex-toolchains.sh
COPY home/ /usr/local/share/codex-sandbox/home/
COPY container-entrypoint.bash /usr/local/bin/container-entrypoint

RUN chmod 0755 /usr/local/bin/container-entrypoint

ENV HOME=/home/codex \
    CODEX_HOME=/home/codex/.codex \
    ELAN_HOME=/home/codex/.elan \
    SDKMAN_DIR=/home/codex/.sdkman \
    NPM_CONFIG_CACHE=/tmp/codex-npm-cache \
    NPM_CONFIG_PREFIX=/home/codex/.local \
    UV_CACHE_DIR=/tmp/codex-uv-cache \
    UV_LINK_MODE=copy \
    GOPATH=/home/codex/go \
    GOCACHE=/tmp/codex-go-cache/build \
    GOMODCACHE=/tmp/codex-go-cache/mod \
    PATH=/usr/local/go/bin:/home/codex/go/bin:/home/codex/.local/bin:${PATH} \
    BASH_ENV=/etc/profile.d/codex-toolchains.sh

USER codex
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/container-entrypoint"]
