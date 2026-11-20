---
name: publish-project-pdf
description: Create or refresh a polished, reproducible PDF from authoritative Org or Markdown project documentation using Pandoc and Typst. Use for PDF publishing, export, typesetting, or visual refinement; not for prose-only edits.
---

# Publish project PDF

Produce a visually polished PDF without weakening the repository's ownership of
its source, theme, build, or generated artifact.

## Establish context

- Read the applicable repository instructions and inspect the working tree
  before changing files.
- Identify the declared documentation source of truth. Prefer explicit project
  guidance over filename conventions; ask only when competing sources are
  genuinely ambiguous.
- Inspect existing document commands, Pandoc defaults, Typst files, output
  locations, ignore rules, and tracked artifacts. Preserve a working local
  pipeline rather than replacing it with this skill's defaults.
- Confirm Pandoc and Typst are available before promising a render. Installing
  or downloading tools, fonts, or Typst packages requires the same permission
  as any other dependency change.

## Establish a pipeline when needed

- Prefer a direct Pandoc reader for the authoritative format and Typst output.
  Do not introduce Markdown as an intermediate when Pandoc can read the source
  format directly.
- Keep inspectable intermediate files and preview images in an ignored build
  directory. Put durable configuration and the final artifact where the
  repository's conventions expect them.
- Use [assets/theme.typ](assets/theme.typ) only when the project has no suitable
  theme. Copy it into the project and adapt the copy; never make a project build
  import the skill asset at runtime. The project-local copy becomes
  authoritative immediately.
- Prefer built-in fonts and repository-local resources so the build works
  offline. Avoid remote Typst packages unless the project deliberately accepts
  that dependency.
- Add the PDF command to the repository's existing task runner when practical.
  Do not introduce a new task runner solely for this workflow.
- Publish the final PDF under `docs/` and track it by default when the user asks
  for an immediately available repository artifact, unless local conventions
  indicate another path. Mark tracked PDFs as binary in Git attributes.
- Document the source file, build command, output path, ignored intermediates,
  and local ownership of the theme. Add concise project instructions requiring
  the PDF to be refreshed when its source changes.

## Apply the visual language

- Use metadata for the project title and authors rather than embedding a
  project identity in a reusable theme.
- Aim for restrained typography, strong hierarchy, generous but efficient
  spacing, readable code, and consistent headers and footers.
- Keep table contents left-aligned even when the table block is centered.
- Place rules beneath primary headings close enough to belong to the heading,
  with visible clearance for descenders.
- Preserve syntax highlighting and wrap or resize long code and URLs without
  letting them cross page margins.
- Treat the starter theme as the stable default. Do not customize its visual
  identity merely from a project's name, subject, or an inferred creative
  association.
- Customize the visual identity only when the user explicitly asks or the
  repository provides evidence such as brand colors, design tokens, documented
  visual guidance, or established styling. Briefly identify that evidence in
  the handoff when customization occurs.

## Render and review

Read [references/visual-review.md](references/visual-review.md) before reviewing
a new or materially changed design.

- Generate the PDF and page previews from the same Typst intermediate.
- Inspect every page, not only the cover and first content page. Iterate on the
  theme or conversion settings until the visual review passes.
- Change documentation prose only when requested or when a source defect is the
  actual cause of a rendering problem. Do not rewrite content merely to make
  layout easier.
- Rebuild the final PDF after every source, configuration, or theme correction.

## Validate and hand off

- Run the document build from a clean command invocation and check Typst
  diagnostics.
- Run relevant repository checks and `git diff --check`. Confirm intermediates
  are ignored and the intended PDF is visible to Git.
- Report the authoritative source, build command, published PDF path, visual
  review performed, and validation result.
- Do not commit unless the user asks. Do not overwrite an established theme or
  broaden the documentation scope without authorization.
