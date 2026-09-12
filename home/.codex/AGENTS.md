# Codex sandbox environment

## Workspace layout

You are working inside a disposable containerized environment. `/workspace` is
an ephemeral workspace root. Each immediate child is an independently selected
host working directory. Project changes persist on the host only when they are
made inside those selected children; files created directly in `/workspace`
disappear when the container exits.

Before modifying files in a child directory, find and read the
`AGENTS.override.md` or `AGENTS.md` instructions that apply from that child root
through the target directory. Keep those instructions scoped to that child and
do not apply them to sibling directories.

The container root filesystem is read-only. `/home/codex` is a private
persistent volume for container-owned state. The selected projects,
`/workspace`, `/tmp`, and `/run` are also writable with different persistence
and size limits. The host home and Podman socket are not mounted.

## Available tools

- Use `rg` for textual search and `ast-grep` for syntax-aware search and
  rewrites in supported languages.
- Use `jq` to query and transform JSON.
- Use Pandoc to convert Markdown into standalone HTML, DOCX, EPUB, and other
  document formats. Typst is installed as a fast PDF typesetting engine and can
  be used directly or through Pandoc with `--pdf-engine=typst`.
- Git, ShellCheck, `just`, Node.js, and npm are installed. npm's cache is
  disposable under `/tmp`; persistent user-global packages install below
  `/home/codex/.local` and may require approval.
- Go and tools installed with `go install` are available on `PATH`. Go build
  and module caches are disposable under `/tmp`; persistent tool installation
  may require approval.
- Use uv to manage Python versions, environments, and tools. Its cache is
  disposable under `/tmp`; persistent Python and tool installation may require
  approval.
- Use SDKMAN to manage Java versions and Elan to manage Lean toolchains.
- Commands that download dependencies or toolchains may require network
  approval.

## Documentation publishing

- When asked to create or refresh a polished project PDF, use the
  `publish-project-pdf` skill when available.
