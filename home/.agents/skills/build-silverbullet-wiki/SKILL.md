---
name: build-silverbullet-wiki
description: Create or evolve a domain-focused SilverBullet knowledge wiki with Repeater cards embedded beside the knowledge they test. Use for wiki structure, Markdown conventions, Repeater integration, styling, placement, parsing safety, or validation; not for general spaced-repetition card pedagogy.
---

Create and progressively improve a focused knowledge base that is
simultaneously a [SilverBullet][silverbullet] wiki and a source of
[Repeater][repeater] spaced-repetition cards.

# Build a SilverBullet wiki

## Establish context

Whether creating a new wiki or working with an existing one:

- Read the applicable repository instructions. If a wiki already
  exists, inspect it before changing files.

- Determine the wiki's subject, language, audience, sources, and
  established conventions from the repository and the user's
  request. Do not assume a particular domain or language.

- Treat Markdown files as the source of truth. Consider knowledge
  prose as primary: Repeater cards are an attached learning mechanism,
  not a separate body of documentation.

- Treat Git history, when present, as the record of the knowledge
  base's evolution. Current pages should contain the best current
  understanding.

## Wiki structure

Let the wiki structure emerge iteratively from the knowledge being
developed. Prefer:

- A small number of meaningful pages;

- Clear headings;

- Useful SilverBullet links between concepts;

- Gradual refactoring of the structure as the knowledge model becomes
  clearer.

Avoid premature deep hierarchies, many tiny pages without a clear
purpose, and duplicated material.

Do not hard-wrap prose in wiki Markdown. Keep each paragraph and each
list item on a single source line and let SilverBullet handle visual
wrapping. Insert a source line break only when Markdown structure or
the intended meaning requires it, such as between Repeater fields.

Do not add a heading that repeats the page name. SilverBullet already
displays the page name as its title; begin the page content directly
and use level-one headings for its main sections.

Keep SilverBullet's automatic table-of-contents widget disabled
globally. Add a table of contents manually to a page only when the
user explicitly requests one for that page.

## Wiki content

Wiki content represents a "map" of the user's current knowledge, and
like its structure, it should emerge iteratively and
conservatively. Do not turn the wiki into a comprehensive
encyclopedia, a copy or summary of a source, or a repository of
material merely because it might someday be useful.

Preserve useful observations from real subjective experience,
including external feedback, difficulties, mistakes, successful
techniques, uncertainty under practical conditions, and areas
requiring further practice.

When incorporating external factual material:

- Prefer authoritative primary sources;

- Record a source when it will matter later for verification or
  further study;

- Do not turn source material wholesale into wiki content;

- Integrate only what contributes to the user's current learning;

- Distinguish source knowledge from the user's personal observations.

Identify errors, ambiguities, missing concepts, and weak reasoning
explicitly. Correct factual errors rather than preserving them for
consistency. Add new material when the user chooses to study it, keep
notes concise and useful for revision, and refactor existing notes and
structure as understanding improves.

Avoid speculative expansion into adjacent topics, mechanically
populating empty sections, or generating large bodies of reference
material merely because they could be useful. Optimize for an
accurate, navigable, progressively improving knowledge model rather
than repository size or apparent completeness.

When modifying existing material:

- Make small, coherent changes;

- Preserve useful user-authored content;

- Improve rather than gratuitously rewrite;

- Identify and flag obsolete or contradicted material when
  appropriate; do not remove it unless the user explicitly requests
  or approves its removal;

- Avoid duplication and keep terminology consistent across pages;

- Preserve meaningful links;

- Keep Repeater cards close to the knowledge from which they derive;

- Validate Repeater parsing after card-related changes.

# Integrate Repeater cards

This skill governs the integration of Repeater cards within the wiki;
it does not prescribe how to create pedagogically effective card
content.

## Protect documentation from Repeater parsing

Repeater detects card syntax from the Markdown source itself. Markdown
code fences do **not** protect examples from being parsed as cards.

Therefore:

- Never put a documentation or example line beginning at column zero
  with `Q:` or `C:`;

- Never include the literal double-colon Repeater shorthand anywhere
  in documentation or examples. Indentation and Markdown code
  formatting do not protect it from the parser;

- Indent Repeater syntax examples in documentation so they cannot be
  parsed.

The examples in this skill are deliberately indented for that
reason. Do not indent real cards in the wiki.

## Terminate every card explicitly

Every Repeater card must be explicitly terminated with `---`. This
applies to both ordinary Q/A cards and cloze cards.

Do not rely on a following heading, code fence, HTML closing tag,
blank line, or the end of an apparent paragraph to terminate a
card. This is particularly important for cloze cards: if a cloze
remains unterminated, subsequent Markdown such as reference-style
links may be interpreted as additional cloze blanks.

An ordinary card should structurally look like this:

```text
<div class="repeater">
    Q: question
    A: answer
    ---
</div>
```

A cloze card should structurally look like this:

```text
<div class="repeater">
    C: statement containing a [cloze].
    ---
</div>
```

## Display cards in SilverBullet

Place each card immediately after the paragraph, list, or section
containing the knowledge it tests. Do not create a separate parallel
card hierarchy or collect cards at the end of a page merely for
convenience unless the user explicitly requests it.

Wrap every real Repeater card in:

```html
<div class="repeater">
...
</div>
```

SilverBullet supports block-level HTML containing Markdown. Keep the
HTML block contiguous: do not insert blank lines between the opening
`<div>` and closing `</div>`, because block-level HTML handling may
terminate at a blank line.

The wiki's SilverBullet styling must contain `space-style` rules that
visually distinguish `.repeater` blocks from the surrounding
knowledge. Keep the shared presentation in the wiki's style page
rather than applying inline styles to individual cards.

Use [assets/repeater-style.md](assets/repeater-style.md) as the default
when the wiki has no established `.repeater` presentation. If the wiki
has no style page, copy the asset into the wiki as its initial style
page. If a style page already exists, merge the asset's `space-style`
block into it without overwriting unrelated rules. Preserve existing
`.repeater` rules when they already provide a deliberate presentation,
unless the user requests a change.

After copying or merging the asset, the wiki owns its local styling;
do not make it import or depend on the skill at runtime. The default
may be adapted to an established visual language, but Repeater blocks
must remain visible. Do not use HTML comments as a substitute for this
convention.

## Validate Repeater changes

Any change that adds, removes, rewrites, moves, or otherwise affects
Repeater cards must be validated before considering the work complete.

Run:

```sh
repeater check . --plain
```

Inspect at least:

- `Cards found`;
- `Files containing cards`;
- `Markdowns parsed`.

The number of cards found must be plausible given the repository
contents. If the count is unexpected, investigate before finishing. Do
not dismiss unexplained extra or missing cards.

For debugging a particular file, use:

```sh
repeater check path/to/file.md --plain
```

Remember that:

- One cloze block can generate multiple cards when it contains
  multiple cloze blanks;

- An unterminated cloze can consume later Markdown and turn unrelated
  `[text]` constructs into additional cards;

- `Total cards indexed in DB` is not the same thing as the number of
  cards found in the current scan.

After modifying cards, the repository-level `repeater check . --plain`
is the final validation.

[silverbullet]: https://silverbullet.md/
[repeater]: https://github.com/shaankhosla/repeater
