FROM debian:trixie-slim

# Node.js LTS
ARG NODE_VERSION=24.21.0
ARG NODE_LINUX_AMD64_SHA256=fd8e59d5a511510f6a298afb548f18c7d2b1be404d8b4a27d94fbe49f56cb2d6
ARG NODE_LINUX_ARM64_SHA256=6ad1325edbdb5649c379b75a237147a666c95d4f9ae8d340fef2d1575d289ad2

# Codex CLI
ARG CODEX_VERSION=0.160.0
ARG CODEX_LINUX_AMD64_SHA256=4fcc47ab57f52ff75363951a8761146cd10c8288bd86fed45487dbb204a16b71
ARG CODEX_LINUX_ARM64_SHA256=7f0fe42ff22ecfa3a47bc4a34f5b22c4218b431a4ec0aba51c7d98299f07900c

# ast-grep
ARG AST_GREP_VERSION=0.45.3

# uv
ARG UV_VERSION=0.12.22
ARG UV_INSTALLER_SHA256=58488ae8dbd0773134c92c85e901430e33f99d975bd7f929d26aa9ab0c2f9390

# Go
ARG GO_VERSION=1.27.1
ARG GO_LINUX_AMD64_SHA256=63d339f0da5ab53635a56f2490a7984dfe12dfcff22ad749f63edaf590168445
ARG GO_LINUX_ARM64_SHA256=3450b45a3f9ee8568792736a5c5e70a1f2e9b36c35a8f74958c03e51d7d92bec

# Repeater
ARG REPEATER_VERSION=0.1.10
ARG REPEATER_LINUX_AMD64_SHA256=cf9e0d0e6873b49349ba585eb98a9a89cc57613b1a70c294ead671ef807bb026
ARG REPEATER_LINUX_ARM64_SHA256=77faea8e465e9675cb7ef0e8854caebc7e379fda6751f00164db3c20c13eed6c

# Typst
ARG TYPST_VERSION=0.15.1
ARG TYPST_LINUX_AMD64_SHA256=a6d077d0a95eed5a2eba715b2dae06be954f624ccbf85758a03f389ded33118c
ARG TYPST_LINUX_ARM64_SHA256=5aa8d74a3d906e60ea12a66ac2f37f8eef1b14cbad7182a745e393a10c23dcee

# SDKMAN!
ARG SDKMAN_VERSION=5.23.1
ARG SDKMAN_NATIVE_VERSION=0.7.34
ARG SDKMAN_INSTALLER_SHA256=8642db91ce900cf406d2cd457c2b3c7b8fe3e4a8fe454192ae6a34df435052ec

# Keep UID/GID 1000 compatible with existing persistent home volumes.
RUN groupadd --gid 1000 codex \
    && useradd --uid 1000 --gid codex --shell /bin/bash --create-home codex

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ansible-core \
        ansible-lint \
        ca-certificates \
        curl \
        elan \
        git \
        just \
        jq \
        libatomic1 \
        libstdc++6 \
        pandoc \
        ripgrep \
        shellcheck \
        unzip \
        xz-utils \
        yamllint \
        zip \
    && rm -rf /var/lib/apt/lists/* \
    && ansible --version \
    && ansible-lint --version \
    && yamllint --version \
    && mkdir -p /home/codex/.codex /home/codex/.sdkman /workspace \
    && chown -R codex:codex /home/codex /workspace

# Install the official Node.js LTS archive for the build architecture.
# Checksums are reviewed from the release's SHASUMS256.txt.
RUN architecture="$(dpkg --print-architecture)" \
    && case "${architecture}" in \
        amd64) node_arch=x64; node_sha256="${NODE_LINUX_AMD64_SHA256}" ;; \
        arm64) node_arch=arm64; node_sha256="${NODE_LINUX_ARM64_SHA256}" ;; \
        *) echo "Unsupported Node.js architecture: ${architecture}" >&2; exit 1 ;; \
    esac \
    && node_archive="node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" \
    && curl --fail --show-error --silent --location \
        "https://nodejs.org/dist/v${NODE_VERSION}/${node_archive}" \
        --output "/tmp/${node_archive}" \
    && printf '%s  %s\n' "${node_sha256}" "/tmp/${node_archive}" | sha256sum --check --strict - \
    && tar --extract --xz --file "/tmp/${node_archive}" --directory /usr/local \
        --strip-components=1 --no-same-owner \
    && rm "/tmp/${node_archive}" \
    && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
    && test "$(node --version)" = "v${NODE_VERSION}" \
    && npm --version

RUN npm install --global \
        "@ast-grep/cli@${AST_GREP_VERSION}" \
    && ast-grep --version \
    && npm cache clean --force

# Install the pinned standalone Codex package after verifying the checksum
# reviewed and recorded from the matching GitHub release.
RUN architecture="$(dpkg --print-architecture)" \
    && case "${architecture}" in \
        amd64) \
            codex_target="x86_64-unknown-linux-musl"; \
            codex_sha256="${CODEX_LINUX_AMD64_SHA256}" \
            ;; \
        arm64) \
            codex_target="aarch64-unknown-linux-musl"; \
            codex_sha256="${CODEX_LINUX_ARM64_SHA256}" \
            ;; \
        *) echo "Unsupported Codex architecture: ${architecture}" >&2; exit 1 ;; \
    esac \
    && if [ "${#codex_sha256}" -ne 64 ] \
        || printf '%s' "${codex_sha256}" | grep --quiet '[^0-9a-f]'; then \
        echo "Set the Codex SHA-256 build argument for ${architecture}." >&2; \
        exit 1; \
    fi \
    && codex_archive="codex-package-${codex_target}.tar.gz" \
    && curl --fail --show-error --silent --location \
        "https://github.com/openai/codex/releases/download/rust-v${CODEX_VERSION}/${codex_archive}" \
        --output "/tmp/${codex_archive}" \
    && printf '%s  %s\n' "${codex_sha256}" "/tmp/${codex_archive}" | sha256sum --check --strict - \
    && mkdir -p /opt/codex \
    && tar --extract --gzip --file "/tmp/${codex_archive}" --directory /opt/codex \
    && rm "/tmp/${codex_archive}" \
    && chmod 0755 /opt/codex/bin/codex /opt/codex/bin/codex-code-mode-host /opt/codex/codex-path/rg \
    && if [ -f /opt/codex/codex-resources/bwrap ]; then \
        chmod 0755 /opt/codex/codex-resources/bwrap; \
    fi \
    && ln -s /opt/codex/bin/codex /usr/local/bin/codex \
    && ln -s /opt/codex/bin/codex-code-mode-host /usr/local/bin/codex-code-mode-host \
    && test "$(codex --no-daemon --version)" = "codex-cli ${CODEX_VERSION}"

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

# Install the official Repeater CLI for the build architecture.
RUN architecture="$(dpkg --print-architecture)" \
    && case "${architecture}" in \
        amd64) \
            repeater_target="x86_64-unknown-linux-gnu"; \
            repeater_sha256="${REPEATER_LINUX_AMD64_SHA256}" \
            ;; \
        arm64) \
            repeater_target="aarch64-unknown-linux-gnu"; \
            repeater_sha256="${REPEATER_LINUX_ARM64_SHA256}" \
            ;; \
        *) echo "Unsupported Repeater architecture: ${architecture}" >&2; exit 1 ;; \
    esac \
    && repeater_archive="repeater-${repeater_target}.tar.xz" \
    && curl --fail --show-error --silent --location \
        "https://github.com/shaankhosla/repeater/releases/download/v${REPEATER_VERSION}/${repeater_archive}" \
        --output "/tmp/${repeater_archive}" \
    && printf '%s  %s\n' "${repeater_sha256}" "/tmp/${repeater_archive}" | sha256sum --check --strict - \
    && tar --extract --xz --file "/tmp/${repeater_archive}" --directory /usr/local/bin \
        --strip-components=1 "repeater-${repeater_target}/repeater" \
    && rm "/tmp/${repeater_archive}" \
    && chmod 0755 /usr/local/bin/repeater \
    && test "$(repeater --version)" = "repeater ${REPEATER_VERSION}"

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
    ANSIBLE_LOCAL_TEMP=/tmp \
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
