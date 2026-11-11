# xoffy

(pron. ch-offy) talk with pptx docx xlsx with Nim (but I don't want to!)

xoffy writes Office files from Nim. Version 0.1 writes PowerPoint decks: slides with text (and a
little Markdown), shapes, arrows, pictures and native tables that you can edit. Word and Excel come next.
It needs the standard library and [zippy](https://github.com/guzba/zippy), and nothing else.

```nim
import xoffy

var deck = newPresentation()
deck.add slide(
  textBox("Hello, Office", box(1.inch, 1.inch, 11.inch, 1.5.inch), Font(size: 54)))
deck.save "hello.pptx"
```

Every file xoffy writes passes the schemas of ECMA-376 and is drawn by LibreOffice on the pages.
It has not been checked in PowerPoint yet: that is the first thing to do before 0.2.

## Pages

The site is https://pietroppeter.github.io/xoffy/ (built by CI from `docs/`, nothing committed).

| page | source | what |
|---|---|---|
| [Home](https://pietroppeter.github.io/xoffy/) | `docs/index.nim` | what xoffy is, the simplest deck, the posts |
| [Devlog](https://pietroppeter.github.io/xoffy/devlog/) | `docs/devlog/index.nim` | every dated post, newest first |
| [Everything you did not want to know about pptx](https://pietroppeter.github.io/xoffy/devlog/inside-pptx/) | `docs/devlog/inside_pptx.nim` | the history of the formats, and what is inside a .pptx |
| [Designing xoffy 0.1](https://pietroppeter.github.io/xoffy/devlog/designing-0-1/) | `docs/devlog/designing_0_1.nim` | the first version, layer by layer, from the zip up |
| [What tabelline needs from xoffy](https://pietroppeter.github.io/xoffy/devlog/tabelline-api/) | `docs/devlog/tabelline_api.nim` | tabelline's tables as native PowerPoint tables, and the API they use |
| [Where xoffy is going](https://pietroppeter.github.io/xoffy/devlog/roadmap/) | `docs/devlog/roadmap.nim` | the releases: decks you have, Excel, Word, charts |

## Layout

- `src/xoffy.nim` exports everything; `src/xoffy/` has one module per layer: `units` (EMU,
  inches, points), `xml`, `zip` (a classic zip, deflate by zippy), `opc` (the package),
  `drawingml` (colours, lines, text, geometry, tables), `images` (PNG, GIF, JPEG), `pptx`.
- `tests/`: `nim r tests/all.nim`.
- `docs/`: the pages, nimib notebooks in tabelline's Munari look (`theme.nim`, `blocks.nim`,
  `review.nim` come from tabelline); `slides.nim` has the blocks that show a deck (`nbSlides`, `nbXml`,
  `nbPackage`). `nim r -d:release docs/all.nim` builds them all; LibreOffice (`soffice`) and
  poppler (`pdftoppm`) draw the slides.
- `tools/setup.sh`: Nim, atlas and the pinned dependencies (`atlas.lock`; nimib and tabelline
  are the `docs` feature).
