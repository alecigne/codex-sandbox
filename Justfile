set positional-arguments := true

# List repository commands.
default:
    @just --list

# Run static checks that do not require Podman.
check:
    bash -n run.bash container-entrypoint.bash sdkman-profile.sh
    shellcheck run.bash container-entrypoint.bash sdkman-profile.sh
    ./run.bash --help >/dev/null
    git diff --check

# Build or refresh the sandbox image.
build:
    ./run.bash --rebuild-only

# Launch Codex; pass directories and Codex arguments as usual.
run *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec ./run.bash "$@"

# List running sandbox containers.
containers:
    podman ps --filter ancestor=codex-sandbox:local

# Open Bash in the running sandbox; pass an ID or name if several are running.
shell container="":
    #!/usr/bin/env bash
    set -euo pipefail

    container="${1-}"
    if [[ -z "${container}" ]]; then
      container_ids="$(podman ps --quiet --filter ancestor=codex-sandbox:local)"
      if [[ -z "${container_ids}" ]]; then
        echo "No running codex-sandbox container found." >&2
        exit 1
      fi

      mapfile -t containers <<< "${container_ids}"
      if (( ${#containers[@]} != 1 )); then
        echo "Multiple codex-sandbox containers are running:" >&2
        printf '  %s\n' "${containers[@]}" >&2
        echo "Run: just shell <container-id-or-name>" >&2
        exit 1
      fi
      container="${containers[0]}"
    fi

    exec podman exec --interactive --tty "${container}" bash --login
