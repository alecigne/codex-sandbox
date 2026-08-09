FROM node:24-bookworm-slim

ARG CODEX_VERSION=0.147.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends bubblewrap ca-certificates git \
    && rm -rf /var/lib/apt/lists/* \
    && npm install --global "@openai/codex@${CODEX_VERSION}" \
    && npm cache clean --force \
    && mkdir -p /home/node/.codex /workspace \
    && chown -R node:node /home/node /workspace

ENV HOME=/home/node \
    CODEX_HOME=/home/node/.codex

USER node
WORKDIR /workspace
