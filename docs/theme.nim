## Every styling decision of xoffy's pages, in one place: tabelline's theme (docs/theme.nim there),
## copied, with xoffy's palette, Ufficio, as Munari's values.
##
## The palette by roles of the design review (devlog, 8 November 2026): each look gives six values,
## paper, ink, primary, secondary, warning and success, and every other colour is mixed from them
## in the browser (`color-mix(in oklab, ...)`), so a palette is six values and a reader can try
## another one on the page:
##
## - the neutrals, ink mixed into paper: `--shade` (outputs, plain notes, row groups), `--line`
##   (rules), `--muted` (grey text), the whole scale `--neutral-0` (the paper) to `--neutral-9`
##   (the ink) for the steps in between, and `--surface`, a whiter sheet;
## - for each colour role, the colour (`--primary`, for shapes and edges), a soft version for
##   backgrounds (`--primary-soft`) and a text version (`--primary-text`); warning has no text
##   version: the warning colour is never text.
##
## Shape says what kind of thing it is (the circle a place, the triangle a warning, the square a
## sheet set apart, drawn as its straight top edge); colour says the role.
##
## Two looks are in every page: Munari, the default, whose rules are the page itself (so a page
## without JavaScript is Munari), and the quaderno (an Italian school exercise book), every rule of
## which is scoped by `html[data-tema="quaderno"]`. The pages share it: `css` is written once to
## `docs/assets/site.css`, and its fonts are the files beside it, in `docs/assets/fonts/`. Built
## with `-d:singleFile`, a page inlines all of it instead (fonts as data URLs), so it is one file
## that works alone, for a one-page preview. No other module of the docs writes CSS or a colour: pages use the blocks of `blocks.nim`, and
## tables take tabelline's `optCssTheme()`, which reads these tokens by name (`--ink`, `--paper`,
## `--line`, `--shade`, `--primary`, `--secondary`, `--font`).

import std/[os, strformat, strutils, base64]

const
  singleFile* = defined(singleFile)
    ## `-d:singleFile`: every page is one file, its style and fonts inlined
  assetsDir* = currentSourcePath().parentDir / "assets"
    ## `docs/assets/`: the files the pages share (deployed with them)
  fontDir = assetsDir / "fonts"

func face(family, file, weight, style: string): string =
  # shared: the font file, beside site.css; singleFile: the font itself, as a data URL
  let src = when singleFile: "data:font/woff2;base64," & encode(staticRead(fontDir / file)) else: "fonts/" & file
  &"@font-face{{font-family:'{family}';src:url({src}) format('woff2');" &
    &"font-weight:{weight};font-style:{style};font-display:swap}}\n"

const fonts = face("Patrick Hand", "patrick-hand.woff2", "400", "normal") &
              face("Atkinson Hyperlegible", "atkinson-regular.woff2", "400", "normal") &
              face("Atkinson Hyperlegible", "atkinson-bold.woff2", "700", "normal") &
              face("Atkinson Hyperlegible", "atkinson-italic.woff2", "400", "italic") &
              face("Jost", "jost-400-normal.woff2", "400", "normal") &
              face("Jost", "jost-400-italic.woff2", "400", "italic") &
              face("Jost", "jost-700-normal.woff2", "700", "normal")

# ------------------------------------------------------------------------------------ the palette

type Look* = object
  ## The six values a look gives; every token is mixed from them.
  paper*, ink*, primary*, secondary*, warning*, success*: string

const
  quadernoLook* = Look(paper: "#FDFDF9", ink: "#2B2D38",
                       primary: "#1F4E99",     # blue pen: headings, links
                       secondary: "#5B9BD5",   # sky blue: notes and cards to go to, bars
                       warning: "#FFD84D", success: "#3FA34D")
    ## The quaderno's values. Its red pen stays a motif of the look (`--red-pen`), not a role.
  haru* = Look(paper: "#FCFAF2",       # 白練 shironeri, white silk
               ink: "#1C1C1C",         # 墨 sumi, ink
               primary: "#E16B8C",     # 紅梅 kōbai, red plum blossom: the circle
               secondary: "#7DB9DE",   # 勿忘草 wasurenagusa, forget-me-not: the square
               warning: "#F7D94C",     # 菜の花 nanohana, rapeseed flower: the triangle
               success: "#86C166")     # 苗 nae, seedling: the fourth
    ## Munari's default palette, Haru (spring): Japanese traditional colours (nipponcolors.com).

  edo* = Look(paper: "#FCFAF2",        # 白練 shironeri, white silk
              ink: "#1C1C1C",          # 墨 sumi, ink
              primary: "#77428D",      # 江戸紫 edomurasaki, Edo purple: the circle, links, the book's notes
              secondary: "#0089A7",    # 新橋 shinbashi, Shinbashi blue: the square, the Python tab
              warning: "#FFB11B",      # 山吹 yamabuki, kerria flower: the triangle, the source box
              success: "#7BA23F")      # 萌黄 moegi, fresh sprouts: numbers in code
    ## The book's palette, Edo (the fashion colours of old Tokyo): the book has one look,
    ## Munari, in these six values (`book/theme/edo.css`, `paletteCss(edo)`).

  ufficio* = Look(paper: "#FAF8F5",    # a sheet of office paper
                  ink: "#1F1E1D",      # toner
                  primary: "#C8553D",  # a slide's warm red: the circle, links
                  secondary: "#2E5EAA",# a document's blue: the square, notes and cards
                  warning: "#F2B134",  # a sticky note's yellow: the triangle
                  success: "#2F8F5B")  # a spreadsheet's green: what works
    ## xoffy's palette, Ufficio (office): one colour for each of the three formats, softened.

  neutralSteps* = [0, 4, 8, 14, 25, 40, 55, 65, 80, 100]  ## ink in paper, % per step `--neutral-0`..`--neutral-9`
  softShare* = 22   ## % of a colour in paper, for `--x-soft`
  textShare* = 50   ## % of a colour in ink, for `--x-text`

  partTints* = ["#FAECAC", "#C7DFEA", "#F1BEC7", "#FDDFC4", "#CDC7DE", "#CAE2B7", "#D7EEEC"]
    ## The categorical palette of the parts of a table (`table_parts.nim`): Haru and its neighbours
    ## (菜の花, 勿忘草, 紅梅, 洒落柿, 藤, 苗, 瓶覗), about 40% in the paper, readable in both looks.

func tokensCss(): string =
  ## The derived tokens, declared once on `html` for both looks.
  for i, s in neutralSteps:
    result.add &"--neutral-{i}: color-mix(in oklab, var(--ink) {s}%, var(--paper));\n"
  result.add "--shade: var(--neutral-1); --line: var(--neutral-3); --muted: var(--neutral-7);\n"
  result.add "--surface: color-mix(in oklab, #FFFFFF 60%, var(--paper));\n"
  for role in ["primary", "secondary", "warning", "success"]:
    result.add &"--{role}-soft: color-mix(in oklab, var(--{role}) {softShare}%, var(--paper));\n"
    if role != "warning":
      result.add &"--{role}-text: color-mix(in oklab, var(--{role}) {textShare}%, var(--ink));\n"

func lookCss(l: Look): string =
  &"--paper: {l.paper}; --ink: {l.ink}; --primary: {l.primary}; --secondary: {l.secondary}; " &
    &"--warning: {l.warning}; --success: {l.success};"

func paletteCss*(l: Look, selector = "html"): string =
  ## The six values of a look and every token mixed from them, on one selector: for a page with
  ## one look, such as the book (`book/bookbuild.nim` puts `paletteCss(edo)` before its theme).
  selector & " {\n" & lookCss(l) & "\n" & tokensCss() & "}\n"

const tokens =
  # Munari names its six values after where they go; the palettes post swaps them on the page.
  &"""html {{
  --m-carta: {ufficio.paper}; --m-inchiostro: {ufficio.ink}; --m-cerchio: {ufficio.primary};
  --m-quadrato: {ufficio.secondary}; --m-triangolo: {ufficio.warning}; --m-quarto: {ufficio.success};
  --paper: var(--m-carta); --ink: var(--m-inchiostro); --primary: var(--m-cerchio);
  --secondary: var(--m-quadrato); --warning: var(--m-triangolo); --success: var(--m-quarto);
""" & tokensCss() & "}\n" &
  "html[data-tema=\"quaderno\"] {\n" & lookCss(quadernoLook) & "\n}\n"

# ---------------------------------------------------------------------------------------- Munari
# After Bruno Munari: flat paper, one geometric sans (Jost), and the three shapes of his books,
# each with a meaning. Nothing that only decorates may look like something to press or drag.
# These rules are the page: they need no script, so a page without JavaScript is Munari.

const munariCss = """
html {
  --hand: "Jost", "Futura", "Century Gothic", system-ui, sans-serif;
  --font: "Jost", "Futura", "Century Gothic", system-ui, sans-serif;
  --mono: ui-monospace, "SF Mono", Menlo, Consolas, "DejaVu Sans Mono", monospace;
  /* the quaderno's own motifs, kept here for the dated posts' own CSS */
  --grid: #D9E7F5;          /* the squares */
  --margin: #E9585B;        /* the red margin rule */
  --postit: #FFF6B8;        /* sticky notes */
  --highlight: rgba(255, 230, 90, .55);
  --tape: rgba(255, 214, 165, .75);
  --edge: #C9D9EC;          /* pale blue rules */
  --red-pen: #C62828;       /* corrections, subheadings, stamps */
  --sq: 20px;               /* one square, about 5 mm */
  /* names from before the tokens, for the dated posts' own CSS */
  --pencil: var(--ink); --pen: var(--ink); --pen-red: var(--primary-text);
  --card: var(--surface); --rule: var(--line); --carta: var(--shade);
  --text: var(--font); --n-0: var(--neutral-0); --n-1: var(--neutral-1); --n-2: var(--neutral-2); --n-3: var(--neutral-3); --n-4: var(--neutral-4);
  --n-5: var(--neutral-5); --n-6: var(--neutral-6); --n-7: var(--neutral-7); --n-8: var(--neutral-8); --n-9: var(--neutral-9);
  --giallo: var(--warning); --blu: var(--secondary);
}
* { box-sizing: border-box; }
[hidden] { display: none !important; }
html { -webkit-text-size-adjust: 100%; }
body {
  margin: 0; color: var(--ink); font: 18px/1.6 var(--font); background-color: var(--paper);
  padding: 0 max(14px, env(safe-area-inset-right, 0px)) 0 max(14px, env(safe-area-inset-left, 0px));
}
body > header, body > main, body > footer { max-width: 50rem; margin: 0 auto; position: relative; }
main { padding-bottom: 2rem; }
header { padding-top: .4rem; }

/* the cover: the three shapes over each other, like sheets of coloured acetate */
.forme { display: block; position: absolute; top: 6.3rem; right: 0; width: 9.5rem; height: 8.5rem; pointer-events: none; }
.forme i { position: absolute; display: block; mix-blend-mode: multiply; }
.forme .cerchio { width: 6.2rem; height: 6.2rem; border-radius: 50%; background: var(--primary); right: 0; top: 0; }
.forme .quadrato { width: 4.6rem; height: 4.6rem; background: var(--secondary); right: 3.6rem; top: 2.6rem; }
.forme .triangolo { width: 5.6rem; height: 4.9rem; background: var(--warning); right: 1.2rem; top: 3.6rem;
  clip-path: polygon(50% 0, 100% 100%, 0 100%); }
.etichetta { margin: 2.4rem 0 1.4rem; position: relative; padding: 0 10.5rem 0 0; min-height: 8.5rem; }
.etichetta .riga span:first-child { display: none; }
.etichetta .riga span:last-child { font: 400 1.25rem/1.3 var(--font); color: var(--ink); }
.etichetta .nome span:last-child { font: 700 3.4rem/1 var(--font); letter-spacing: -.03em; }
.etichetta .riga:last-child:not(.nome) span:last-child { font-size: .8rem; letter-spacing: .18em; text-transform: uppercase; color: var(--muted); }
.etichetta .nome a { color: inherit; text-decoration: none; }
@media (max-width: 560px) {
  .forme { transform: scale(.62); transform-origin: top right; top: 6rem; }
  .etichetta { padding-right: 6.4rem; min-height: 6rem; }
  .etichetta .nome span:last-child { font-size: 2.5rem; }
}
.crumbs { display: flex; justify-content: space-between; gap: 1rem; flex-wrap: wrap; padding-top: 1rem;
  font: 700 .74rem/1 var(--font); letter-spacing: .16em; text-transform: uppercase; }
.crumbs a { color: var(--ink); text-decoration: none; }
.lede { font-size: 1.3rem; line-height: 1.45; color: var(--ink); margin: 0 0 1.2rem; }
.kicker { font: 700 .74rem/1 var(--font); letter-spacing: .2em; text-transform: uppercase; color: var(--primary-text); margin: 0; }

/* type: one sans, big and plain; sections marked by the circle */
h1, h2, h3, h4 { font-family: var(--font); font-weight: 700; color: var(--ink); letter-spacing: -.015em; line-height: 1.15; }
h1 { font-size: 2.9rem; line-height: 1.05; margin: 1.5rem 0 .4rem; }
h2 { font-size: 1.85rem; display: block; padding: 0 0 0 2.4rem; margin: 3rem 0 .9rem; position: relative; scroll-margin-top: 1rem; }
h2::before { content: ""; position: absolute; left: 0; top: .2em; width: 1.5rem; height: 1.5rem;
  background: var(--part, var(--primary)); border-radius: 50%; }
h3 { font-size: 1.25rem; color: var(--primary-text); margin: 2rem 0 .5rem; scroll-margin-top: 1rem; }
h2 .num { color: var(--muted); margin-right: .35rem; }
a { color: var(--ink); text-decoration-color: var(--primary); text-decoration-thickness: 2px; text-underline-offset: 2px; }
a:hover { background: var(--primary-soft); }
strong { font-weight: 700; }
p, li { max-width: 46rem; }
blockquote { margin: 1.2rem 0; padding: .7rem 1rem; border-left: 6px solid var(--neutral-4); }
blockquote p { margin: .3rem 0; }
hr { border: 0; border-top: 2px solid var(--ink); margin: 2rem 0; }
mark { background: var(--warning-soft); padding: 0 .15em; }
img { max-width: 100%; }

/* code: a white sheet with a black edge; outputs on grey paper */
pre { margin: 1rem 0; }
pre > code, pre.nb-output { display: block; overflow-x: auto; font: 13px/1.55 var(--mono); padding: .8rem 1rem; }
body pre > code { font-size: 13px; }
pre > code { background: var(--surface); border: 2px solid var(--ink); }
pre.nb-output { background: var(--shade); border: 0; white-space: pre; color: var(--ink); }
pre.nb-output::before { content: "output"; display: block; margin-bottom: .1rem;
  font: 700 .66rem/1.4 var(--font); letter-spacing: .2em; text-transform: uppercase; color: var(--primary-text); }
:not(pre) > code { font: .88em var(--mono); background: var(--shade); padding: .05em .3em; }
.hljs-keyword { color: var(--primary-text); font-weight: 700; } .hljs-string { color: var(--secondary-text); }
.hljs-number, .hljs-literal { color: var(--success-text); }
.hljs-comment { color: var(--muted); font-style: italic; } .hljs-type { color: var(--ink); font-weight: 700; }
.hljs-built_in { color: var(--primary-text); } .hljs-meta { color: var(--muted); }

/* tables: no tape, no squares; the rules come from optCssTheme(), from the tokens */
.tabella { position: relative; margin: 1.6rem 0 1.8rem; padding: 16px 0 10px; overflow-x: auto; }  /* a wide table scrolls in its box */
.tabella .tb_title { font-family: var(--hand); font-size: 125%; letter-spacing: -.01em; }
.tabella td code { overflow-wrap: anywhere; }  /* long names in a cell wrap on a phone */
main table:not(.tb_table) { border-collapse: collapse; margin: 1rem 0; background: var(--surface); }
main table:not(.tb_table) th, main table:not(.tb_table) td { border: 1px solid var(--line); padding: .35rem .6rem; text-align: left; vertical-align: top; }

/* the indice: numbers on circles, as the section headings */
.indice { padding: 1rem 0; margin: 1.4rem 0 2rem; max-width: 36rem;
  border-top: 3px solid var(--ink); border-bottom: 3px solid var(--ink); }
.indice h2.indice-title { font: 700 .78rem/1 var(--font); letter-spacing: .2em; text-transform: uppercase;
  color: var(--ink); padding: 0; margin: 0 0 .9rem; display: block; }
.indice h2.indice-title::before { display: none; }
.indice ol { margin: 0; }
.indice > ol { list-style: none; padding: 0; counter-reset: voce; font: 500 1.08rem/1.5 var(--font); }
.indice > ol > li { counter-increment: voce; position: relative; padding-left: 2.3rem; margin: .35rem 0; }
.indice > ol > li::before { content: counter(voce); position: absolute; left: 0; top: .1rem; width: 1.5rem; height: 1.5rem;
  border-radius: 50%; background: var(--primary); color: #fff; font: 700 .78rem/1.5rem var(--font); text-align: center; }
.indice > ol > li.parte-secondary::before { background: var(--secondary); color: var(--ink); }
.indice > ol > li.parte-success::before { background: var(--success); color: var(--ink); }
.indice ol ol { font: 400 .95rem/1.45 var(--font); padding-left: 0; margin: .15rem 0 .3rem; list-style: none; }
/* back to the indice: an arrow at the end of every heading, on the pages that have an indice */
.su { display: none; margin-left: .45rem; padding: .2em .45em; font-size: .55em; vertical-align: .25em;
  color: var(--muted); text-decoration: none; border: 1px solid var(--line); line-height: 1; }
.su::before { content: "↑"; }
.su:hover, .su:focus-visible { color: var(--ink); border-color: var(--ink); }
body:has(#indice) .su { display: inline-block; }
.indice ol ol li::before { content: "— "; color: var(--muted); }
.indice a { text-decoration-line: none; color: var(--ink); }
.indice a:hover { text-decoration-line: underline; }

/* sheets set apart (notes, cards, gallery cards): flat paper with the square's straight top edge,
   in the colour of their kind; nothing on them to press. A warning carries the triangle. */
.nota { padding: 1rem 1.2rem; margin: 1.3rem 0; background: var(--shade); border-top: 5px solid var(--ink); }
.nota.info { background: var(--secondary-soft); border-top-color: var(--secondary); }
.nota.done, .nota.code { background: var(--success-soft); border-top-color: var(--success); }
.nota.missing { background: var(--primary-soft); border-top-color: var(--primary); }
.nota.warning { background: var(--warning-soft); border-top-color: var(--warning); }
.nota > :first-child { margin-top: 0; } .nota > :last-child { margin-bottom: 0; }
.nota .titolo { font: 700 1.1rem var(--font); color: var(--ink); display: block; }
.nota .numero { font: 700 .72rem/1.2 var(--font); letter-spacing: .14em; color: var(--muted); display: block; }
.nota.warning { position: relative; padding-left: 3.1rem; }
.nota.warning::before, .nota.warning::after { content: ""; position: absolute; left: 1.1rem; top: 1.1rem; width: 1.4rem; height: 1.25rem;
  clip-path: polygon(50% 0, 100% 100%, 0 100%); }
.nota.warning::before { background: var(--ink); }
.nota.warning::after { background: var(--warning); transform: scale(.7); transform-origin: 50% 68%; }
.timbro { display: inline-block; font: 700 .8rem/1.6 var(--font); letter-spacing: .12em; text-transform: uppercase;
  color: var(--ink); border: 2px solid var(--ink); padding: 0 .5rem; }
.timbro.ok { color: var(--success-text); border-color: var(--success); }
.timbro.ko { background: var(--primary-soft); }

/* cards (nbCards, nbCard): a grid of notes */
.cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(14rem, 1fr)); gap: 1rem; margin: 1.2rem 0; }
.cards .nota { margin: 0; }
.cards .nota .titolo + p { margin-top: .3rem; }

/* a gallery (nbGallery, nbGalleryCard): cards to swipe sideways, numbered */
.nb-galleria { display: flex; align-items: flex-start; gap: .8rem; overflow-x: auto; scroll-snap-type: x mandatory;
  padding: .2rem 0 .8rem; counter-reset: nb-scheda; -webkit-overflow-scrolling: touch; }
.nb-galleria::after { content: ""; flex: 0 0 .2rem; }
.nb-galleria > .nb-scheda { flex: 0 0 min(84%, 24rem); scroll-snap-align: start; overflow-x: auto; padding: .7rem .9rem .8rem;
  background: var(--shade); border: 0; border-top: 5px solid var(--secondary); counter-increment: nb-scheda; }
.nb-galleria > .nb-scheda::before { content: counter(nb-scheda); display: block; font: 700 .72rem/1.2 var(--font); letter-spacing: .14em; color: var(--muted); }
.nb-galleria > .nb-scheda > h3 { margin: .15rem 0 .4rem; font-size: 1.15rem; }
.nb-galleria > .nb-scheda[data-label]::before { content: attr(data-label) " · " counter(nb-scheda); text-transform: uppercase; }
.nb-galleria > .nb-scheda p { font-size: .94rem; line-height: 1.45; margin: 0 0 .5rem; }
.nb-scheda pre { margin: .4rem 0; }
body .nb-scheda pre > code { font-size: 12.5px; white-space: pre-wrap; overflow-wrap: anywhere; }
.nb-scheda .tabella { margin: .4rem 0 0; }
.nb-scheda .tabella table { font-size: 14px !important; }
.accanto { display: flex; flex-wrap: wrap; gap: 0 .6rem; justify-content: center; align-items: flex-start; }

/* tabs (nbTabs): the same example in Nim, Python and R; the choice holds for the whole page */
.lingue { margin: 1.2rem 0; }
.lingue-tab { display: flex; gap: 0; flex-wrap: wrap; }
.lingue-tab button { font: 700 .72rem/1.6 var(--font); letter-spacing: .1em; text-transform: uppercase; color: var(--ink);
  background: transparent; border: 2px solid var(--ink); border-bottom: 0; padding: .15rem .8rem; cursor: pointer; margin-right: -2px; }
.lingue-tab button[aria-selected="true"] { background: var(--ink); color: var(--paper); }
.lingue-pannello { border-top: 2px solid var(--ink); padding-top: .2rem; }
.lingue-pannello > pre:first-child { margin-top: .6rem; }

/* the code of a table, folded under it (nbShowCode) */
details.codice { margin: -.8rem 0 1.6rem; }
details.codice > summary { list-style: none; cursor: pointer; display: inline-block; font: 700 .68rem/1.6 var(--font);
  letter-spacing: .12em; text-transform: uppercase; color: var(--ink); border-bottom: 2px solid var(--secondary); }
details.codice > summary::-webkit-details-marker { display: none; }
details.codice > summary::before { content: "+ show code"; }
details.codice[open] > summary::before { content: "− hide code"; }
details.codice pre { margin: .4rem 0 0; }
body /* a drawing (nbDrawing): a Pele diagram in the page's colours */
.disegno { margin: 1.4rem 0; }
.disegno svg { display: block; max-width: 100%; height: auto; margin: 0 auto; --pele-bg: var(--paper); --pele-fg: var(--ink);
  --pele-muted: var(--muted); --pele-line: var(--ink); --pele-border: var(--ink); --pele-surface: var(--surface);
  --pele-surface-alt: var(--neutral-1); --pele-accent: var(--secondary); }
.disegno figcaption { margin-top: .5rem; font-size: .9rem; color: var(--muted); }
body details.codice pre > code { font-size: 12.5px; }

/* code, folded under its name and its length (nbFoldCode) */
details.foldcode { margin: 0; border-top: 1px solid var(--line); border-bottom: 1px solid var(--line); }
details.foldcode + details.foldcode { border-top: 0; }
details.foldcode:not(:has(+ details.foldcode)) { margin-bottom: 1.6rem; }
details.foldcode > summary { list-style: none; cursor: pointer; padding: .45rem 0; display: flex; gap: .6rem;
  align-items: baseline; }
details.foldcode > summary::-webkit-details-marker { display: none; }
details.foldcode > summary::before { content: "+"; font-weight: 700; width: .8rem; color: var(--secondary); }
details.foldcode[open] > summary::before { content: "−"; }
details.foldcode > summary > span { margin-left: auto; font-size: .8rem; white-space: nowrap; }
details.foldcode pre { margin: .2rem 0 .8rem; }
body details.foldcode pre > code { font-size: 12.5px; }

/* the parts of a table (nbParts): a switch between the data and its parts, and their legend */
.parti { list-style: none; padding: 0; margin: .8rem 0; }
.parti li { margin: .35rem 0; padding-left: 2rem; position: relative; line-height: 1.45; }
.tinta-parte { position: absolute; left: 0; top: .25em; width: 1.3rem; height: 1rem; outline: 1px solid var(--line); }
.parti .colore { color: var(--muted); font-size: .88em; }
.mostra-parti { font: 700 .72rem/1.6 var(--font); letter-spacing: .14em; text-transform: uppercase; cursor: pointer;
  border: 2px solid var(--ink); background: transparent; color: var(--ink); padding: .3rem .8rem; margin: .2rem 0 0; }
.mostra-parti[aria-pressed="true"] { background: var(--ink); color: var(--paper); }

/* swatches (nbSwatches): a colour beside its name */
.tinte { display: grid; grid-template-columns: repeat(auto-fill, minmax(9.5rem, 1fr)); gap: .8rem; margin: 1rem 0; }
.tinte .tinta { font-size: .86rem; line-height: 1.35; }
.tinte .tinta span { display: block; height: 2.4rem; margin-bottom: .3rem; outline: 1px solid var(--neutral-2); }
.tinte .tinta strong { display: block; font-size: .95rem; }

/* parts of a long page (nbPart): a label, then the sections' circles take the part's colour */
.parte { font: 700 .74rem/1 var(--font); letter-spacing: .2em; text-transform: uppercase; margin: 3.4rem 0 -1.2rem; color: var(--muted); }
.parte-secondary ~ h2 { --part: var(--secondary); } .parte-success ~ h2 { --part: var(--success); }
/* a later part wins over an earlier one, whatever its colour: one more class for the second part on */
.parte ~ .parte-primary ~ h2 { --part: var(--primary); } .parte ~ .parte-secondary ~ h2 { --part: var(--secondary); }
.parte ~ .parte-success ~ h2 { --part: var(--success); }

/* the specs page (nbSpecs): each capability folds open; examples carry a pass stamp */
details.spec { background: var(--shade); border: 0; border-top: 5px solid var(--secondary); margin: .8rem 0; padding: .5rem 1rem; }
details.spec > summary { cursor: pointer; font-size: 1.1rem; }
details.spec > summary b { font: 700 1.2rem var(--font); color: var(--ink); margin-right: .4rem; }
details.spec .counts { color: var(--muted); font-size: .85rem; }
details.spec .purpose { display: block; color: var(--ink); font-size: .95rem; margin: .2rem 0 .3rem; }
.req { border-top: 2px dashed var(--line); padding: .4rem 0 .6rem; }
.req h4 { font: 700 1rem var(--font); color: var(--primary-text); margin: .6rem 0 .2rem; }
.example { margin: .6rem 0 1rem; }
.example .ex-head { display: flex; gap: .6rem; align-items: center; font-size: .8rem; color: var(--muted); }
.ex-out summary { cursor: pointer; font: 700 1rem var(--font); color: var(--muted); }
.scen { background: var(--paper); padding: .4rem .8rem; margin: .5rem 0; }
.scen-name { font: 700 1rem var(--font); color: var(--ink); }
.scen ul { margin: .2rem 0; padding-left: 1.2rem; }
.kw { font: 600 .75rem var(--font); letter-spacing: .08em; padding: 0 .3rem; border-radius: 4px; }
.kw.when { background: var(--secondary-soft); } .kw.then { background: var(--success-soft); } .kw.and, .kw.given { background: var(--neutral-2); }
.src { font-size: .8rem; color: var(--muted); }
details.links summary { cursor: pointer; }

/* a part of a page folded under a line (nbFold): closed at first */
details.fold { border-top: 2px solid var(--ink); border-bottom: 2px solid var(--ink); margin: 1rem 0 1.6rem; }
details.fold > summary { list-style: none; cursor: pointer; padding: .55rem 0; display: flex; gap: .6rem; font: 700 1rem var(--font); }
details.fold > summary::-webkit-details-marker { display: none; }
details.fold > summary::before { content: "+"; width: .8rem; color: var(--secondary); }
details.fold[open] > summary::before { content: "−"; }
details.fold[open] > summary { border-bottom: 1px solid var(--line); }

/* the API reference (nbApi): one sheet per name, its straight top edge in ink */
.api { border-top: 2px solid var(--ink); margin: 1.6rem 0 0; padding: .3rem 0 .2rem; scroll-margin-top: 1rem; }
.api h4 { display: flex; align-items: baseline; gap: .6rem; flex-wrap: wrap; margin: .2rem 0 .4rem; }
.api h4 code { font: 700 1.05rem var(--mono); color: var(--ink); background: none; padding: 0; overflow-wrap: anywhere; }
.api .api-anchor { margin-left: auto; font: 700 1rem var(--font); color: var(--muted); text-decoration: none; padding: 0 .3rem; }
.api .api-anchor:hover, .api:target .api-anchor { color: var(--primary-text); }
.api .api-kind { font: 700 .7rem/1 var(--font); letter-spacing: .16em; text-transform: uppercase; color: var(--muted); }
.api pre.api-sig { margin: .3rem 0; }
.api > p { margin: .4rem 0; }
.api > p code, .api li code { overflow-wrap: anywhere; }
.api .api-none { color: var(--muted); font-style: italic; }
.api .api-links { font-size: .82rem; color: var(--muted); }
.api .api-links a { color: var(--ink); }
.api details.api-ex { margin: .5rem 0; }
.api details.api-ex > summary { cursor: pointer; font: 700 .9rem var(--font); color: var(--muted); }

/* the look switch: ink, the selected one filled */
.tema { display: flex; justify-content: flex-end; gap: 0; margin: .6rem 0 0; }
.tema button { font: 700 .72rem/1.6 var(--font); letter-spacing: .14em; text-transform: uppercase; cursor: pointer;
  border: 2px solid var(--ink); background: transparent; color: var(--ink); padding: .2rem .7rem; }
.tema button:last-child { border-left: 0; }
.tema button[aria-pressed="true"] { background: var(--ink); color: var(--paper); }

/* footer, with Munari's motto */
footer { font: 400 .9rem/1.5 var(--font); color: var(--muted); padding: 1rem 0 3rem; text-align: center;
  border-top: 2px solid var(--ink); }
body > footer { margin-top: 2rem; }
footer a { color: var(--ink); }
.motto { display: block; font: 700 1.35rem/1.3 var(--font); color: var(--ink); margin: .2rem 0 1rem; }
.motto span { display: block; font: 400 .74rem/2 var(--font); letter-spacing: .2em; text-transform: uppercase; color: var(--primary-text); }
details.source { margin-top: 1rem; text-align: left; }
details.source summary { cursor: pointer; }
details.source pre { overflow-x: auto; }   /* the whole source, top to bottom: it is opened on purpose */
/* a screenshot with numbered circles (nbScreenshot): the circle is a place */
.schermata { margin: 1rem 0; width: min(47%, 15rem); }
.schermata > div { position: relative; }
.schermata img { display: block; width: 100%; height: auto; border: 1px solid var(--line); }
.schermata .punto { position: absolute; transform: translate(-50%, -50%); width: 1.25rem; height: 1.25rem; border-radius: 50%;
  display: flex; align-items: center; justify-content: center; font: 700 .72rem/1 var(--font);
  background: var(--primary); color: var(--paper); box-shadow: 0 0 0 2px var(--paper); }
.schermata figcaption { font-size: .8rem; line-height: 1.35; color: var(--muted); margin-top: .3rem; }

/* xoffy: XML attributes; a deck, drawn by LibreOffice, each slide a sheet with a thin edge */
.hljs-attr { color: var(--success-text); }
.deck { margin: 1.4rem 0 1.8rem; }
.deck img { display: block; width: 100%; height: auto; border: 1px solid var(--line); background: var(--surface); }
.deck .slides { display: grid; gap: .7rem; }
.deck.small .slides { grid-template-columns: repeat(auto-fill, minmax(min(100%, 220px), 1fr)); }
.deck figcaption { margin-top: .45rem; font-size: .82rem; line-height: 1.4; color: var(--muted); }
.deck figcaption a { font-weight: 700; }
details.foldcode > summary code { overflow-wrap: anywhere; min-width: 0; }
"""

# ------------------------------------------------------------------------------------ the quaderno
# An Italian school exercise book, the other look: squared paper, a red margin, headings in blue
# pen with a highlighter stroke, code on index cards, outputs on sticky notes, tables taped in.
# Every rule is scoped by `html[data-tema="quaderno"]` and changes only what differs from Munari.

const quadernoRules = """
html {
  --hand: "Patrick Hand", "Segoe Print", "Comic Sans MS", cursive;
  --font: "Atkinson Hyperlegible", system-ui, -apple-system, "Segoe UI", sans-serif;
  --pen: var(--primary); --pen-red: var(--red-pen);
}
body { font: 17px/1.6 var(--font);
  background-image:
    linear-gradient(var(--grid) 1px, transparent 1px),
    linear-gradient(90deg, var(--grid) 1px, transparent 1px);
  background-size: var(--sq) var(--sq); }
main { padding-left: 2.2rem; border-left: 3px double var(--margin); }
@media (max-width: 640px) { main { padding-left: .9rem; } }
header { padding-top: 0; }

/* the cover label */
.etichetta { margin: 2.2rem auto 1.6rem; max-width: 30rem; background: var(--surface); min-height: auto;
  border: 2px solid var(--primary); border-radius: 18px; padding: 1rem 1.4rem 1.1rem;
  box-shadow: 4px 5px 0 color-mix(in srgb, var(--primary) 15%, transparent); }
.etichetta::before { content: ""; position: absolute; inset: 6px; border: 1px solid var(--edge); border-radius: 13px; pointer-events: none; }
.etichetta .riga { display: flex; gap: .6rem; align-items: baseline; border-bottom: 1.5px dotted var(--edge); padding: .15rem 0; }
.etichetta .riga span:first-child { display: inline; font: 600 .72rem/1 var(--font); letter-spacing: .12em; text-transform: uppercase; color: var(--muted); min-width: 5.2rem; }
.etichetta .riga span:last-child { font: 1.55rem/1.25 var(--hand); color: var(--primary); }
.etichetta .nome span:last-child { font: 2.3rem/1.25 var(--hand); letter-spacing: normal; }
.etichetta .riga:last-child:not(.nome) span:last-child { font-size: 1.55rem; letter-spacing: normal; text-transform: none; color: var(--primary); }
.crumbs { font: 1.05rem var(--hand); letter-spacing: normal; text-transform: none; padding-top: .8rem; }
.crumbs a { color: var(--primary); text-decoration-line: underline; }
.lede { font-size: 1.15rem; line-height: inherit; }
.kicker { font-weight: 600; letter-spacing: .14em; color: var(--red-pen); }

/* headings in blue pen, with a highlighter stroke */
h1, h2, h3, h4 { font-family: var(--hand); font-weight: 400; color: var(--primary); letter-spacing: normal; }
h1 { font-size: 2.6rem; line-height: 1.15; }
h2 { font-size: 2.05rem; margin: 2.6rem 0 .8rem -.3rem; display: inline-block; position: static; padding: 0 .3rem;
  background: linear-gradient(transparent 55%, var(--highlight) 55%, var(--highlight) 92%, transparent 92%); }
h2::before { content: none; }
h3 { font-size: 1.55rem; margin-top: 1.8rem; color: var(--red-pen); }
h2 .num { color: var(--red-pen); }
a { color: var(--primary); text-decoration-color: currentcolor; text-decoration-thickness: 1.5px; }
a:hover { background: none; }
blockquote { background: var(--postit); border-radius: 2px 2px 14px 2px; border-left: 0;
  box-shadow: 2px 3px 6px rgba(0,0,0,.08); transform: rotate(-.4deg); }
hr { border-top: 2px dashed var(--edge); }
mark { background: var(--highlight); }

/* code on index cards, outputs on sticky notes */
pre > code, pre.nb-output { border-radius: 6px; }
pre > code { border: 1px solid var(--edge); border-left: 5px solid var(--primary);
  box-shadow: 2px 3px 0 color-mix(in srgb, var(--primary) 8%, transparent); }
pre.nb-output { background: var(--postit); box-shadow: 2px 3px 6px rgba(0,0,0,.07); }
pre.nb-output::before { font: .95rem var(--hand); letter-spacing: normal; text-transform: none; color: var(--muted); }
:not(pre) > code { background: color-mix(in srgb, var(--primary) 7%, transparent); border-radius: 4px; }
.hljs-string { color: var(--success-text); }
.hljs-number, .hljs-literal { color: var(--secondary-text); }
.hljs-type { color: var(--primary); font-weight: inherit; } .hljs-built_in { color: var(--secondary-text); }

/* tables pasted in, with a strip of tape, on squared paper */
.tabella { padding: 18px 14px 12px; background: var(--surface);
  box-shadow: 0 1px 2px rgba(0,0,0,.08), 3px 5px 14px rgba(0,0,0,.07); border-radius: 2px; }
.tabella::before { content: ""; position: absolute; top: -11px; left: 50%; width: 110px; height: 24px;
  margin-left: -55px; background: var(--tape); transform: rotate(-2deg); box-shadow: 0 1px 2px rgba(0,0,0,.08); }
.tabella .tb_table { background-image: linear-gradient(var(--grid) 1px, transparent 1px),
  linear-gradient(90deg, var(--grid) 1px, transparent 1px); background-size: 12px 12px; }
.tabella .tb_title { font-size: 150%; letter-spacing: normal; }
main table:not(.tb_table) th, main table:not(.tb_table) td { border-color: var(--edge); }

/* the indice: a sticky note with the headings */
.indice { background: var(--postit); padding: 1rem 1.3rem 1.1rem; max-width: 34rem; border: 0;
  box-shadow: 2px 4px 10px rgba(0,0,0,.1); transform: rotate(.5deg); border-radius: 2px 2px 18px 2px; }
.indice h2.indice-title { font: 400 1.7rem/1.15 var(--hand); letter-spacing: normal; text-transform: none; background: none;
  color: var(--red-pen); margin: 0 0 .4rem; }
.indice > ol { list-style: decimal; padding-left: 1.5rem; counter-reset: none; font: 1.2rem/1.45 var(--hand); }
.indice > ol > li { counter-increment: none; position: static; padding-left: 0; margin: 0; }
.indice > ol > li::before { content: none; }
.indice ol ol { font: 1.05rem/1.45 var(--hand); padding-left: 1.1rem; margin: 0; }
.indice ol ol li::before { content: "– "; }
.indice a { color: var(--primary); }

/* notes (nbNote): a sticky note, coloured by its kind; a warning carries the triangle */
.nota { background: var(--postit); padding: .8rem 1.1rem; border-top: 0; border-radius: 2px 2px 14px 2px;
  box-shadow: 2px 3px 8px rgba(0,0,0,.09); transform: rotate(-.3deg); }
.nota.info { background: var(--secondary-soft); } .nota.done, .nota.code { background: var(--success-soft); }
.nota.missing { background: var(--primary-soft); } .nota.warning { background: var(--warning-soft); }
.nota .titolo { font: 1.3rem var(--hand); color: var(--red-pen); }
.nota.warning { padding-left: 3rem; }
.nota.warning::before, .nota.warning::after { left: .9rem; top: .9rem; }
.timbro { font: 1.05rem var(--hand); letter-spacing: normal; text-transform: none; color: var(--red-pen); border-color: var(--red-pen);
  border-radius: 8px; transform: rotate(-4deg); }
.timbro.ok { color: var(--success-text); border-color: var(--success-text); }
.nb-galleria > .nb-scheda { background: var(--surface); border: 1px solid var(--line); }
.accanto .tabella { padding-left: 6px; padding-right: 6px; }

/* tabs and switches in blue pen */
.lingue-tab button { font: 1rem var(--hand); letter-spacing: normal; text-transform: none; color: var(--primary);
  background: var(--surface); border: 1.5px solid var(--primary); border-bottom: 0; margin-right: -1.5px; }
.lingue-tab button[aria-selected="true"] { background: var(--primary); color: var(--paper); }
.lingue-pannello { border-top: 1.5px solid var(--primary); }
details.codice { margin-top: -1rem; }
details.codice > summary { font: 1rem var(--hand); letter-spacing: normal; text-transform: none; color: var(--primary); border-bottom: 0; }

/* specs */
details.spec { background: var(--surface); border: 1.5px solid var(--line); border-radius: 10px; }
details.spec > summary b { font: 1.45rem var(--hand); color: var(--primary); }
.req h4 { font: 1.3rem var(--hand); color: var(--red-pen); }
.ex-out summary { font: 1.05rem var(--hand); }
.scen { background: var(--shade); border-radius: 8px; }
.scen-name { font: 1.1rem var(--hand); color: var(--primary); }

/* the look switch */
.tema button { font: 1rem var(--hand); letter-spacing: normal; text-transform: none; color: var(--primary);
  background: var(--surface); border: 1.5px solid var(--primary); padding: .1rem .7rem; }
.tema button:first-child { border-radius: 10px 0 0 10px; } .tema button:last-child { border-radius: 0 10px 10px 0; border-left: 0; }
.tema button[aria-pressed="true"] { background: var(--primary); color: var(--paper); }
.forme, .motto { display: none; }

footer { font: 1.05rem var(--hand); border-top: 0; }
body > footer { margin-top: 0; }
footer a { color: var(--primary); }
"""

func scoped*(rules, scope: string): string =
  ## Puts `scope` before every selector of `rules`; `html` itself becomes `scope`. Rules inside
  ## `@media` are scoped too; comments are kept.
  var i = 0
  while i < rules.len:
    if rules.continuesWith("/*", i):
      let e = rules.find("*/", i) + 2
      result.add rules[i ..< e]; i = e
    elif rules[i] in {'}', '\n', ' '}:
      result.add rules[i]; inc i
    elif rules.continuesWith("@media", i):
      let e = rules.find('{', i) + 1
      result.add rules[i ..< e]; i = e
    else:
      let e = rules.find('{', i)
      var sels: seq[string]
      for s in rules[i ..< e].split(','):
        let s = s.strip
        sels.add(if s == "html": scope else: scope & " " & s)
      let close = rules.find('}', e)
      result.add sels.join(", ") & " " & rules[e .. close]; i = close + 1

const quadernoCss = scoped(quadernoRules, "html[data-tema=\"quaderno\"]")

const css* = fonts & tokens & munariCss & quadernoCss
  ## All the CSS of a page: Munari, the default, then the quaderno, scoped.

proc assetHref*(name, pageFile: string): string =
  ## The link from a page (its HTML file) to a file the pages share, `docs/assets/<name>`.
  relativePath(assetsDir / name, absolutePath(pageFile).parentDir).replace('\\', '/')

proc siteCss*(pageFile: string, extra = ""): string =
  ## What a page puts in its head for its style: a link to `docs/assets/site.css` (written when
  ## it changed), relative to the page; with `-d:singleFile`, the CSS itself. `extra` is CSS of
  ## other modules every page has (the review mode's).
  when singleFile:
    "<style>\n" & css & extra & "</style>"
  else:
    let file = assetsDir / "site.css"
    if not fileExists(file) or readFile(file) != css & extra: writeFile(file, css & extra)
    &"""<link rel="stylesheet" href="{assetHref("site.css", pageFile)}">"""

# ----------------------------------------------------------------------------------------- tables

const tokenColours* = ["--paper", "--shade", "--line", "--muted", "--ink", "--surface",
  "--primary", "--primary-soft", "--primary-text", "--secondary", "--secondary-soft", "--secondary-text",
  "--warning", "--warning-soft", "--success", "--success-soft", "--success-text"]
  ## The tokens a page may name in a table colour, as `tint("--secondary")`.

func tint*(token: string): string =
  ## A token as a CSS colour, for tabelline's colour arguments: `style.fill(tint("--secondary"))`.
  doAssert token in tokenColours, "not a token: " & token
  "var(" & token & ")"

func tintMix*(token: string, share: int, other = "--paper"): string =
  ## `share`% of a token in another (the paper by default), for a scale drawn from the palette.
  doAssert token in tokenColours and other in tokenColours
  &"color-mix(in oklab, var({token}) {share}%, var({other}))"

# ----------------------------------------------------------------------------------- review mode

