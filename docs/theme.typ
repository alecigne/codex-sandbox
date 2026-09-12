#let ink = rgb("#1f2937")
#let navy = rgb("#17233c")
#let accent = rgb("#0f7892")
#let muted = rgb("#687386")
#let rule = rgb("#d7dee8")
#let panel = rgb("#f3f6f9")
#let inline-code = rgb("#e8f1f4")

#let conf(
  title: none,
  authors: (),
  keywords: (),
  date: none,
  abstract: none,
  cols: 1,
  margin: (x: 22mm, top: 21mm, bottom: 19mm),
  paper: "a4",
  lang: "en",
  region: "US",
  font: ("Libertinus Serif",),
  fontsize: 10pt,
  sectionnumbering: none,
  doc,
) = {
  set document(
    title: title,
    author: authors.map(author => author.name),
    keywords: keywords,
  )

  set text(
    lang: lang,
    region: region,
    font: font,
    size: fontsize,
    fill: ink,
    hyphenate: true,
  )

  if title != none {
    page(
      paper: paper,
      margin: 25mm,
      fill: navy,
      header: none,
      footer: none,
    )[
      #v(1fr)
      #line(length: 42mm, stroke: 3pt + accent)
      #v(14pt)
      #text(size: 9pt, weight: "semibold", tracking: 0.14em, fill: accent)[
        PROJECT DOCUMENTATION
      ]
      #v(8pt)
      #text(size: 34pt, weight: "bold", fill: white)[#title]
      #v(1fr)
      #text(size: 9pt, fill: rgb("#aebbd0"))[Rootless Podman / Codex CLI]
    ]
  }

  set page(
    paper: paper,
    margin: margin,
    numbering: none,
    header: {
      set text(font: "Libertinus Serif", size: 8pt, fill: muted)
      grid(
        columns: (1fr, auto),
        align: (left, right),
        text(weight: "semibold", tracking: 0.08em)[CODEX SANDBOX],
        [Project documentation],
      )
      v(3pt)
      line(length: 100%, stroke: 0.5pt + rule)
    },
    footer: context {
      set text(font: "Libertinus Serif", size: 8pt, fill: muted)
      align(center, counter(page).display("1"))
    },
  )

  set par(justify: true, leading: 0.65em)
  set heading(numbering: sectionnumbering)
  set list(indent: 1.15em, body-indent: 0.55em, spacing: 0.35em)
  set enum(indent: 1.15em, body-indent: 0.55em, spacing: 0.35em)
  set table(
    inset: (x: 6pt, y: 5pt),
    stroke: (x: none, y: 0.5pt + rule),
    fill: (_, y) => if y == 0 {
      rgb("#deebef")
    } else if calc.odd(y) {
      rgb("#f8fafc")
    } else {
      none
    },
  )

  show link: set text(fill: accent)
  show table: it => {
    set align(left)
    it
  }
  show heading.where(level: 1): it => {
    block(above: 1.2em, below: 0.75em, breakable: false)[
      #grid(
        columns: (1fr,),
        row-gutter: 9pt,
        text(size: 20pt, weight: "bold", fill: navy)[#it.body],
        rect(width: 100%, height: 1.2pt, fill: accent, stroke: none),
      )
    ]
  }
  show heading.where(level: 2): it => block(
    above: 1.1em,
    below: 0.5em,
    breakable: false,
  )[
    #text(size: 13.5pt, weight: "semibold", fill: navy)[#it.body]
  ]
  show heading.where(level: 3): it => block(
    above: 0.9em,
    below: 0.35em,
    breakable: false,
  )[
    #text(size: 11.5pt, weight: "semibold", fill: accent)[#it.body]
  ]
  show raw.where(block: true): it => block(
    width: 100%,
    fill: panel,
    stroke: (left: 2pt + accent),
    radius: (right: 4pt),
    inset: (x: 10pt, y: 8pt),
    above: 0.7em,
    below: 0.8em,
    breakable: true,
  )[
    #set text(font: "DejaVu Sans Mono", size: 8pt)
    #it
  ]
  show raw.where(block: false): it => box(
    fill: inline-code,
    radius: 2pt,
    inset: (x: 2.5pt, y: 1pt),
  )[
    #set text(font: "DejaVu Sans Mono", size: 0.82em, fill: navy)
    #it
  ]
  if authors.len() > 0 {
    align(center)[
      #authors.map(author => author.name).join([, ])
    ]
  }

  if date != none {
    align(center, text(fill: muted)[#date])
  }

  if abstract != none {
    block(fill: panel, radius: 4pt, inset: 12pt)[
      #text(weight: "semibold", fill: navy)[Overview] #abstract
    ]
  }

  if cols == 1 {
    doc
  } else {
    columns(cols, doc)
  }
}
