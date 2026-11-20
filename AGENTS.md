# AGENTS.md

## Project purpose

This repository builds and launches a secure, CLI-only containerized
environment for Codex CLI.

The launcher must preserve two isolation layers:

1. Rootless Podman exposes only the selected projects beneath
   `/workspace` and a private persistent container home at
   `/home/codex`.

2. Codex keeps its normal Linux `bubblewrap`/seccomp sandbox
   enabled. The image selects the `container-workspace` profile in
   `/etc/codex/config.toml`, extending `:workspace` with Git writes,
   command networking, and writes to container-owned tool/cache
   directories. Keep other mounted projects outside the conversation's
   write scope and keep `.agents`, `.codex`, and `.aws`
   protections. Preserve normal Codex configuration precedence and
   approval defaults; do not force policies in launcher arguments or
   overwrite the persistent user's configuration.

Do not weaken or bypass either layer to make a command work. In
particular, do not add the host home, SSH configuration, host
environment, or Podman socket as container mounts, and do not disable
the Codex sandbox. If unprivileged user namespaces or `bubblewrap`
fail, report the host prerequisite instead.

## Repository map

- `Containerfile` builds the Debian-based image and installs Codex
  CLI, development tools, sandbox dependencies, and SDKMAN.

- `image/` mirrors the installed paths of repository-managed image
  files.

  - `image/usr/local/bin/container-entrypoint` overlays the home
    template, seeds SDKMAN into the persistent home, and executes the
    requested command.

  - `image/usr/local/bin/codex-sandbox-menu` runs the Gum menus and
    starts Codex with the selected conversation directory and writable
    project roots.

  - `image/etc/codex/config.toml` supplies the system-wide Codex
    defaults.

  - `image/etc/profile.d/codex-toolchains.sh` restores toolchain paths
    and loads SDKMAN for Bash commands through `BASH_ENV`.

  - `image/usr/local/share/codex-sandbox/home/` is the template for
    the global Codex guidance and personal skills refreshed for every
    session.

- `run.bash` builds the image when needed and launches the disposable
  Podman container.

- `Justfile` provides common build, validation, launch, and
  container-shell commands.

- `docs/` contains the Pandoc defaults, project-local Typst theme, and
  tracked PDF generated from `README.org`.

- `README.org` is the user-facing setup, usage, isolation, and cleanup
  guide.

## Design constraints

- Keep the container disposable and its root filesystem
  read-only. Only the selected projects, the ephemeral `/workspace`
  root, the Podman-managed home volume, `/tmp`, and `/run` should be
  writable.

- Keep the persistent volume limited to container-owned state such as
  Codex credentials/session data, SDKMAN, and installed JDKs.

- Keep the process unprivileged: preserve `--userns=keep-id`, dropped
  capabilities, `no-new-privileges`, and the PID limit unless a change
  has a clearly documented security rationale.

- Preserve SELinux compatibility for the project bind mount.

- Do not bake credentials or host-specific paths into the image or
  scripts.

- Pin the Node.js, Codex CLI, and SDKMAN versions through their build
  arguments; treat version and checksum bumps as explicit dependency
  updates. Use the npm version bundled with the pinned Node.js
  archive.

- Keep scripts Bash-based, non-interactive where practical, and strict
  with `set -euo pipefail`.

- Quote shell expansions and use long-form flags where clarity
  matters.

- Keep changes minimal; avoid adding orchestration or dependencies
  that this small launcher does not need.

- Load the host's YAML configuration from
  `${XDG_CONFIG_HOME:-$HOME/.config}/codex-sandbox/config.yaml`,
  overridden by `CODEX_SANDBOX_CONFIG`. Its `workspace` mapping
  assigns names to host paths.  With no arguments, offer Resume, New
  conversation (choose a primary project and optional additional
  writable projects), and Quit. Explicit directories or `--` bypass
  the menu and launch Codex directly, forwarding everything after
  `--`. Start in the first explicit directory, otherwise `/workspace`;
  other explicit directories become writable roots through
  `--add-dir`.  All normal launches mount every registered
  project. Reuse registered names for matching host paths and add
  unregistered explicit paths by basename.  Only empty-workspace mode
  bypasses a configured workspace.  Without a default configuration,
  direct launches continue to work with only the explicitly supplied
  mounts.

- Keep mount availability separate from conversation write scope. Do
  not automatically pass every mounted project through `--add-dir`, or
  force a saved conversation's working directory when opening Resume.

- Hand over to Codex with `exec` after menu selection. Exiting Codex
  ends the container with its exit status; only picker cancellation
  returns to the menu.

- Keep workspace configuration separate from Codex session state. The
  user supplies the mounts required by resumed conversations; do not
  filter history, infer additional mounts, or create placeholder
  conversations.

## Working on changes

- Update `README.org` conservatively. Do not add confusing walls of
  texts. Be concise.

- Keep exact image-managed tool versions and checksums in
  `Containerfile`.  Do not repeat them in `README.org`; use
  placeholders in update examples so version-only dependency updates
  do not require README or PDF changes.

- Treat `README.org` as the documentation source of truth. After
  changing it, run `just pdf` and include the refreshed
  `docs/codex-sandbox.pdf`.

- Keep this repository's PDF build self-contained and reproducible
  from repository-owned files.

- Never print, inspect, copy, or delete the persistent home volume's
  credentials unless the user explicitly asks. Removing
  `codex-sandbox-home` is destructive.

- Do not assume Podman or nested user namespaces are available in the
  current development environment. Perform static checks when runtime
  validation is not possible, and state what could not be exercised.

- Do not change unrelated user work in a dirty worktree.

## Git discipline

- Gitea is the canonical remote. Local `master` tracks `gitea/master`;
  GitHub is used for pull-request review and GitHub Releases.

- Use topic branches with a short semantic prefix such as `feat/`,
  `fix/`, or `chore/`. Pull requests are a discipline rather than an
  enforced protection, so the owner may occasionally commit directly
  to `master`.

- Never create commits. The owner creates signed commits and must
  retain control of their signatures. When useful, suggest a concise
  plain-English commit message without a Conventional Commits prefix.

- Do not merge with GitHub's merge, squash, or rebase buttons. After
  review, the owner fast-forwards `master` locally with `git merge
  --ff-only`, then pushes the unchanged signed commits to Gitea and
  GitHub. GitHub records the pull request as indirectly merged.

- Releases are started manually through the GitHub `Release` workflow
  after the intended commit reaches `master`. The owner selects
  `patch`, `minor`, or `major`; the workflow creates a GitHub tag and
  release, attaches the tracked PDF from that commit under a versioned
  filename, and publishes no package or container image.

- Treat incompatible launcher or sandbox-option changes as major
  releases, backward-compatible capabilities as minor releases, and
  fixes or compatible dependency updates as patch releases.

- After a GitHub release, the owner fetches its tags from GitHub and
  pushes all local tags to Gitea. Never push, merge, tag, or start a
  release unless the owner explicitly requests that external action.

## Validation

Run the checks relevant to the edited files:

```bash
for script in run.bash image/usr/local/bin/* image/etc/profile.d/*.sh tests/*.bash; do
  bash -n "$script" || exit
done
shellcheck run.bash image/usr/local/bin/* image/etc/profile.d/*.sh tests/*.bash
bash tests/launcher.bash
bash tests/workspace-menu.bash
podman build --tag codex-sandbox:local --file Containerfile .
./run.bash --help
```

`shellcheck` and Podman may not be installed everywhere; report
skipped checks rather than weakening the implementation. For changes
to container isolation, inspect the resulting `podman run` arguments
and perform runtime validation when Podman is available.
