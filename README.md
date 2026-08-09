# Codex sandbox

A small, CLI-only launcher for running Codex inside a container. There is no
VS Code and no Dev Container tooling.

Two isolation layers are retained:

1. Rootless Podman exposes only the selected project and a private container
   home.
2. Codex runs generated commands through its normal Linux `bubblewrap` and
   seccomp sandbox using `workspace-write` mode.

## Start Codex

With rootless Podman available:

```bash
~/src/codex-sandbox/run.bash ~/src/my-project
```

The image is built automatically the first time. You then get the ordinary
interactive Codex terminal interface. Sign in when prompted.

To use the current directory as the project:

```bash
~/src/codex-sandbox/run.bash
```

To rebuild after changing the image:

```bash
~/src/codex-sandbox/run.bash --rebuild ~/src/my-project
```

Arguments after `--` are passed to Codex:

```bash
~/src/codex-sandbox/run.bash ~/src/my-project -- --model gpt-5.4
```

## What Codex can see

- The selected project, writable at `/workspace`.
- The container's read-only image.
- A private, persistent `/home/node` Podman volume containing Codex login and
  session state.
- Private temporary filesystems at `/tmp` and `/run`.

The launcher does not mount the real host home, SSH configuration, environment,
or Podman API socket. The container is removed when Codex exits; its private home
volume remains so login state persists.

## Verify host isolation

Create a recognizable file outside the selected project on the host:

```bash
printf 'host-only\n' > ~/codex-must-not-see.txt
```

Launch the sandbox on some project, then ask Codex:

> Try to read `/home/MY_HOST_USERNAME/codex-must-not-see.txt`. Show me every
> host-backed mount you can identify, and check whether the Podman API socket is
> accessible.

The file should not exist. The only host directory mount should be the selected
project at `/workspace`; `/home/node` is a Podman-managed volume, not the host
home.

You can also ask Codex to run:

```bash
find /home -maxdepth 2 -print
test ! -S /run/podman/podman.sock && echo 'Podman API socket is not mounted'
cat /proc/self/mountinfo
```

If ordinary commands fail with a `bwrap` or namespace error, stop there. Do not
disable the Codex sandbox. The host's rootless Podman configuration must support
unprivileged user namespaces before relying on both isolation layers.

## Remove persistent Codex state

After all sandbox containers have stopped:

```bash
podman volume rm codex-sandbox-home
```

This permanently deletes the container's Codex credentials and session state.

## Remaining boundary

Codex needs network access to communicate with OpenAI, so the outer container
has Podman's normal outbound network access. Commands spawned by Codex remain
subject to Codex's `workspace-write` network restrictions and approval policy.
No outer egress allowlist has been added yet.
