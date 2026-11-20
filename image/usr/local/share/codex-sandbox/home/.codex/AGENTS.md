# Codex sandbox environment

## Container environment

You are working in a disposable container. Selected host project directories
are mounted beneath `/workspace`; changes inside those mounts persist on the
host. Other files created under `/workspace`, `/tmp`, and `/run` disappear when
the container exits.

The container root filesystem is read-only. `/home/codex` is a private
persistent volume for container-owned state. The host home and Podman socket
are not mounted. Codex's own sandbox remains enabled.

The image's default `container-workspace` permission profile allows network
access, writes to `.git` in the conversation's workspace roots, and writes to
`~/.cache`, `~/.local`, `~/.sdkman`, `~/.elan`, and `~/go`. Routine downloads,
tool installation into those directories, and Git writes do not need sandbox
escalation under this profile. Other mounted projects are not automatically
writable. `.agents`, `.codex`, and `.aws` remain protected. User configuration
and explicit CLI options can select different permissions.

## Available tools

- Use `rg` for textual search and `ast-grep` for syntax-aware search and
  rewrites in supported languages.
- Use `jq` to query and transform JSON.
- Ansible Core, `ansible-lint`, and `yamllint` are installed only for authoring
  and local validation. Never run Ansible commands that connect to or change
  remote hosts, including check mode, and do not query dynamic inventories.
  Local-only commands such as `ansible-lint`, `yamllint`, `ansible-doc`,
  `ansible-config`, and `ansible-playbook --syntax-check` are allowed.
- Use Pandoc to convert Markdown into standalone HTML, DOCX, EPUB, and other
  document formats. Typst is installed as a fast PDF typesetting engine and can
  be used directly or through Pandoc with `--pdf-engine=typst`.
- Git, ShellCheck, `just`, Node.js, and npm are installed. npm's cache is
  disposable under `/tmp`; persistent user-global packages install below
  `/home/codex/.local`.
- Playwright system libraries for headless Chromium, Firefox, and WebKit are
  installed. Use the project's Playwright dependency and run
  `npx playwright install chromium firefox webkit` for matching browsers,
  cached in the persistent home. Do not use `install-deps` or `--with-deps`
  against the read-only image. Save reports and traces inside the selected
  project.
- Go and tools installed with `go install` are available on `PATH`. Go build
  and module caches are disposable under `/tmp`; installed tools persist in
  `/home/codex/go`.
- Repeater is installed for validating Markdown spaced-repetition cards. Run
  `repeater check PATH --plain` as directed by applicable project instructions
  or skills.
- Use uv to manage Python versions, environments, and tools. Its cache is
  disposable under `/tmp`; installed Python versions and tools persist under
  `/home/codex/.local`.
- Use SDKMAN to manage Java versions and Elan to manage Lean toolchains.

## Git commit timestamps

- Always use the project's established local timezone for Git commits. Infer it
  from recent author and committer timestamps when possible; otherwise default
  to `Europe/Paris`.
- Set `TZ` for the commit command, for example `TZ=Europe/Paris git commit ...`,
  so author and committer timestamps use the correct current daylight-saving
  offset.

## Documentation publishing

- When asked to create or refresh a polished project PDF, use the
  `publish-project-pdf` skill when available.
