# AGENTS.md

## Project purpose

This repository builds and launches a secure, CLI-only containerized environment
for Codex CLI. It is deliberately small and does not use VS Code or Dev
Container tooling.

The launcher must preserve two isolation layers:

1. Rootless Podman exposes only the selected project at `/workspace` and a
   private persistent container home at `/home/codex`.
2. Codex keeps its normal Linux `bubblewrap`/seccomp sandbox enabled in
   `workspace-write` mode with approvals requested on demand.

Do not weaken or bypass either layer to make a command work. In particular, do
not add the host home, SSH configuration, host environment, or Podman socket as
container mounts, and do not disable the Codex sandbox. If unprivileged user
namespaces or `bubblewrap` fail, report the host prerequisite instead.

## Repository map

- `Containerfile` builds the Node-based image and installs Codex CLI, sandbox
  dependencies, and SDKMAN.
- `run.bash` builds the image when needed and launches the disposable Podman
  container.
- `Justfile` provides common build, validation, launch, and container-shell
  commands.
- `container-entrypoint.bash` overlays image-managed home files, seeds SDKMAN
  into the persistent home volume, and then executes the requested command.
- `home/` is the sparse image-managed container home template. Its global Codex
  guidance documents the container layout and available tools for every
  session.
- `sdkman-profile.sh` loads SDKMAN for Bash commands through `BASH_ENV`.
- `README.md` is the user-facing setup, usage, isolation, and cleanup guide.

## Design constraints

- Keep the container disposable and its root filesystem read-only. Only the
  selected project, the Podman-managed home volume, `/tmp`, and `/run` should be
  writable.
- Keep the persistent volume limited to container-owned state such as Codex
  credentials/session data, SDKMAN, and installed JDKs.
- Keep the process unprivileged: preserve `--userns=keep-id`, dropped
  capabilities, `no-new-privileges`, and the PID limit unless a change has a
  clearly documented security rationale.
- Preserve SELinux compatibility for the project bind mount.
- Do not bake credentials or host-specific paths into the image or scripts.
- Pin the Codex CLI and SDKMAN versions through their build arguments; treat
  version and checksum bumps as explicit dependency updates.
- Keep scripts Bash-based, non-interactive where practical, and strict with
  `set -euo pipefail`.
- Quote shell expansions and use long-form flags where clarity matters.
- Keep changes minimal; avoid adding orchestration or dependencies that this
  small launcher does not need.

## Working on changes

- Update `README.md` whenever behavior, prerequisites, CLI syntax, persistence,
  mounts, or the security boundary changes.
- Never print, inspect, copy, or delete the persistent home volume's credentials
  unless the user explicitly asks. Removing `codex-sandbox-home` is destructive.
- Do not assume Podman or nested user namespaces are available in the current
  development environment. Perform static checks when runtime validation is not
  possible, and state what could not be exercised.
- Do not change unrelated user work in a dirty worktree.

## Validation

Run the checks relevant to the edited files:

```bash
bash -n run.bash container-entrypoint.bash sdkman-profile.sh
shellcheck run.bash container-entrypoint.bash sdkman-profile.sh
podman build --tag codex-sandbox:local --file Containerfile .
./run.bash --help
```

`shellcheck` and Podman may not be installed everywhere; report skipped checks
rather than weakening the implementation. For changes to container isolation,
also verify the expectations documented under **Verify host isolation** in
`README.md`.
