set positional-arguments := true

# List repository commands.
default:
    @just --list

# Run static checks that do not require Podman.
check:
    bash -n run.bash container-entrypoint.bash toolchain-profile.sh
    shellcheck run.bash container-entrypoint.bash toolchain-profile.sh
    ./run.bash --help >/dev/null
    git diff --check

# Configure this clone to sign commits with the project owner's GPG key.
configure-signing:
    git config --local gpg.format openpgp
    git config --local user.signingkey 477F40FC229A19209161500BD935EEC81422C918
    git config --local commit.gpgsign true
    @echo "Configured commit signing for this clone."

# Render README.org as a styled PDF through Pandoc and Typst.
pdf:
    mkdir -p build
    pandoc --defaults=docs/pdf.yaml --output=build/codex-sandbox.typ README.org
    typst compile --root=. build/codex-sandbox.typ docs/codex-sandbox.pdf

# Build or refresh the sandbox image.
build:
    ./run.bash --build

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
