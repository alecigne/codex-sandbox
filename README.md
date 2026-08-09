# Codex sandbox

A small, CLI-only launcher for running Codex inside a container. There
is no VS Code and no Dev Container tooling.

Two isolation layers are retained:

1. Rootless Podman exposes only the selected project and a private
   container home.

2. Codex runs generated commands through its normal Linux `bubblewrap`
   and seccomp sandbox using `workspace-write` mode.

## Start Codex

With rootless Podman available:

```bash
~/src/codex-sandbox/run.bash ~/src/my-project
```

The image is built automatically the first time. You then get the
ordinary interactive Codex terminal interface. Sign in when prompted.

To use the current directory as the project:

```bash
~/src/codex-sandbox/run.bash
```

To rebuild after changing the image:

```bash
~/src/codex-sandbox/run.bash --rebuild ~/src/my-project
```

### Update SDKMAN

SDKMAN's bootstrap URL is mutable, so the image pins its exact SHA-256
checksum as well as the CLI and native component versions. A build
that encounters a new bootstrap script fails intentionally instead of
silently installing different code.

These pins control the SDKMAN installation used to seed a new persistent
container home. Rebuilding the image does not replace SDKMAN in an existing
home volume, preserving its installed JDKs and other state.

To update the pin, confirm the intended release on SDKMAN's [GitHub
releases page](https://github.com/sdkman/sdkman-cli/releases), then
inspect and hash the current bootstrap script:

```bash
curl --fail --show-error --silent --location "https://get.sdkman.io?rcupdate=false" --output /tmp/install-sdkman.sh
grep '^export SDKMAN_\(VERSION\|NATIVE_VERSION\)=' /tmp/install-sdkman.sh
sha256sum /tmp/install-sdkman.sh
```

Update `SDKMAN_VERSION`, `SDKMAN_NATIVE_VERSION`, and
`SDKMAN_INSTALLER_SHA256` together in `Containerfile`, review the
script's changes, and rebuild the image. SDKMAN's published GitHub
checksum is for its release ZIP, not for this bootstrap script, so it
cannot be used as `SDKMAN_INSTALLER_SHA256`.

Arguments after `--` are passed to Codex:

```bash
~/src/codex-sandbox/run.bash ~/src/my-project -- --model gpt-5.4
```

## Use multiple Java versions

SDKMAN is installed and loaded automatically in Bash commands. Its
files and downloaded SDKs live in the persistent container home, so
installed JDKs survive container replacement and image rebuilds. Its
automatic startup connectivity check is disabled because Codex
commands do not have network access by default; commands that actually
need the network still request approval normally. The entrypoint enforces this
setting for existing home volumes as well as newly seeded ones.

Ask Codex to run SDKMAN commands, or use them from a Bash shell in the
container:

```bash
sdk list java
sdk install java 21.0.12-tem
sdk install java 17.0.20-tem
sdk default java 21.0.12-tem
java -version
```

For a project-specific JDK, create an SDKMAN environment file in the
project:

```bash
sdk env init
```

Edit `.sdkmanrc` to select the desired version, then activate it with
`sdk env`. SDKMAN may need network approval when Codex runs commands
that list or download JDKs.

## What Codex can see

- The selected project, writable at `/workspace`.

- The container's read-only image.

- A private, persistent `/home/node` Podman volume containing Codex
  login and session state, SDKMAN, and installed JDKs.

- Private temporary filesystems at `/tmp` and `/run`.

The launcher does not mount the real host home, SSH configuration,
environment, or Podman API socket. The container is removed when Codex
exits; its private home volume remains so login state persists.

Podman's `keep-id` user namespace keeps the host and container user
IDs aligned.  The project bind mount uses a private SELinux relabel
(`:Z` in short volume syntax) so it remains accessible on
SELinux-enforcing hosts.

## Verify host isolation

Create a recognizable file outside the selected project on the host:

```bash
printf 'host-only\n' > ~/codex-must-not-see.txt
```

Launch the sandbox on some project, then ask Codex:

> Try to read `/home/MY_HOST_USERNAME/codex-must-not-see.txt`. Show me every
> host-backed mount you can identify, and check whether the Podman API socket is
> accessible.

The file should not exist. The only host directory mount should be the
selected project at `/workspace`; `/home/node` is a Podman-managed
volume, not the host home.

You can also ask Codex to run:

```bash
find /home -maxdepth 2 -print
test ! -S /run/podman/podman.sock && echo 'Podman API socket is not mounted'
cat /proc/self/mountinfo
```

If ordinary commands fail with a `bwrap` or namespace error, stop
there. Do not disable the Codex sandbox. The host's rootless Podman
configuration must support unprivileged user namespaces before relying
on both isolation layers.

## Remove persistent Codex state

After all sandbox containers have stopped:

```bash
podman volume rm codex-sandbox-home
```

This permanently deletes the container's Codex credentials and session
state.  It also deletes SDKMAN and all JDKs installed through it.

## Remaining boundary

Codex needs network access to communicate with OpenAI, so the outer
container has Podman's normal outbound network access. Commands
spawned by Codex remain subject to Codex's `workspace-write` network
restrictions and approval policy.  No outer egress allowlist has been
added yet.
