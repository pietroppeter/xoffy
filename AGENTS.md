# Working on xoffy

Notes for coding agents (and people) changing this repository. How it is laid out is in README.md;
the plan is in the devlog post *Where xoffy is going* (`docs/devlog/roadmap.nim`) and BACKLOG.md.

## Code

- The library (`src/xoffy/`) needs only Nim's standard library and zippy (deflate). A new
  dependency has to save a release's worth of work.
- Everything is a plain Nim value (a slide, a grid, a theme), turned into XML by a writer at the
  end: a function from a value to a string, nothing kept between calls except the package.
- The same input gives the same bytes: no dates, no random ids, zip entries in order.
- Write the smallest XML that does the job, in the order the schemas ask for. Every deck the tests
  and the pages write must pass the ECMA-376 schemas (the anthropic pptx skill's
  `scripts/office/validate.py` checks them) and open in LibreOffice.
- Names live beside tabelline's (both are imported together): `TextAlign`, `Edge`, `GridRow`,
  `GridCell`, `Grid`, `markdown`. Check a new exported name against tabelline and the std lib.
- `nim r tests/all.nim` runs the tests.

## Setup

- In a fresh checkout or sandbox, run `sh tools/setup.sh` first (Nim, atlas, libpcre3, the
  dependencies pinned in `atlas.lock`). The pages also need LibreOffice (`soffice`) and poppler
  (`pdftoppm`) to draw the slides; without them a page says so and links the file.
- nimib and tabelline are the `docs` feature of `xoffy.nimble`. To change one: `atlas use` or edit
  the feature, `atlas install --feature=docs`, then `atlas pin --feature=docs` and commit
  `atlas.lock` and `nim.cfg`.

## Pages

- Every page is a nimib notebook in `docs/` that calls `nb.useXoffy(...)` after `nbInit`, in
  tabelline's Munari look with the palette `ufficio` (`docs/theme.nim`), with review mode.
  `docs/theme.nim`, `docs/blocks.nim`, `docs/review.nim` and `docs/assets/review.js` come from
  tabelline: change them there first when the change is not about xoffy.
- Blocks, not HTML: a page is Markdown in `nbText`, nimib's blocks, `nbTable` (tabelline), the
  blocks of `docs/blocks.nim`, and those of `docs/slides.nim` (`nbSlides`, `nbXml`, `nbPackage`).
  No HTML, CSS or colours in a page; a new kind of block goes in `blocks.nim` or `slides.nim`, its
  CSS in `theme.nim`.
- A deck on a page is shown as LibreOffice draws it (`nbSlides deck, "name"`), and the file is
  linked. Fonts the machine lacks fall back: say so in the caption when it shows.
- Explain from the simplest and most fundamental up, from zero, and end a living page or a
  design post with how it is built.
- A devlog post is `docs/devlog/<slug>.nim`, first line
  `## devlog: dd Mon yyyy X | title | lede` (X: A, B, C for posts of the same day); it is dated and
  not rewritten afterwards. A new page gets a line in README.md and an import in `docs/all.nim`.
- The HTML and the decks are not committed: CI builds every page (`docs/all.nim`) and deploys
  `docs/` to GitHub Pages from `main`. Check every page at 390px.

## Previews and PRs

- Show Pietro a published preview of the pages before asking to merge; he reviews on his phone.
- Nothing goes to `main` without his go. One clean PR per change.
