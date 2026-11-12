## The home page, docs/index.html: what xoffy is, the simplest deck that shows it, and the posts.
## Kept up to date as xoffy changes; dated posts are in the devlog.
import std/os
import nimib
import xoffy
import blocks, slides

let docs = currentSourcePath().parentDir
nbInit
nb.doc.filename = docs / "index.html"
nb.useXoffy(section = "Office files from Nim", cadence = "since November 2026",
            title = "xoffy: Office files from Nim",
            description = "xoffy writes PowerPoint files from Nim, with Word and Excel next: native slides, shapes, pictures and tables.")

nbTitle "xoffy · pronounced ch-offy", "Office files from Nim", """
**xoffy** writes PowerPoint files from Nim: slides with text, shapes, pictures and native tables
that you can edit. Each file passes the schemas of the standard, and LibreOffice draws every slide on
these pages (PowerPoint itself is the next check). Word and Excel come next. It needs the standard library and [zippy](https://github.com/guzba/zippy), and nothing else.
Its tagline is Pietro's: *talk with pptx, docx and xlsx from Nim (but I don't want to!)*. xoffy
talks to them, so you don't have to.
"""

nbText: """
## The simplest deck

A presentation, one slide, one text box. Lengths are in inches, centimetres or points; the slide
is 16:9, as PowerPoint makes it.
"""

nbCode:
  var deck = newPresentation()
  deck.add slide(
    textBox("Hello, Office", box(1.inch, 1.inch, 11.inch, 1.5.inch), Font(size: 54)))
  deck.save "hello.pptx"
nbSlides deck, "hello"

nbText: """
A little more: Markdown in a text box, a shape with text in it, an arrow, a picture made in Nim,
and a table PowerPoint can edit.
"""

nbCode:
  var s = slide(textBox(markdown("Office files from **Nim**: *text*, `code`, x^2^ and [links](https://nim-lang.org)",
                                 Font(size: 28)), box(0.8.inch, 0.5.inch, 11.inch, 1.inch)))
  s.add shape(gEllipse, box(0.8.inch, 2.inch, 2.4.inch, 2.4.inch), rgb"C8553D", "a shape", Font(size: 20, color: rgb"FFFFFF"))
  s.add connector(3.6.inch, 3.2.inch, 5.inch, 3.2.inch, line(rgb"1F1E1D", 2.pt, tail = ahTriangle))
  s.add picture(png(160, 120, proc (x, y: int): (int, int, int) = (46 + x, 94 + y, 170)),
                5.4.inch, 2.inch, w = 3.2.inch)
  var g = newGrid(@[@["format", "since"], @["pptx", "0.1"], @["docx", "later"], @["xlsx", "later"]],
                  colWidth = 1.5.inch)
  g.setBorders(line(rgb"1F1E1D", 0.75.pt), {edBottom})
  s.add tableFrame(g, 9.2.inch, 2.inch)
  deck = newPresentation()
  deck.add s
nbSlides deck, "a-little-more"

nbText: """
## Posts

How xoffy is made, and why, from the simplest parts up.
"""
nbCards "the posts":
  nbCard("Everything you did not want to know about pptx", "devlog/inside-pptx/", "history and insides", nkInfo):
    nbText "Where PowerPoint's files come from, the format war that made them a standard, and what is inside one: a zip, a package, DrawingML, a slide."
  nbCard("Designing xoffy 0.1", "devlog/designing-0-1/", "0.1", nkDone):
    nbText "What the first version does, built from the zip up: each layer, its code, and the slide it makes."
  nbCard("What tabelline needs from xoffy", "devlog/tabelline-api/", "the first user", nkCode):
    nbText "How a tabelline table becomes a native PowerPoint table, the API it uses, and what it will need next."
  nbCard("Where xoffy is going", "devlog/roadmap/", "roadmap", nkPlain):
    nbText "From one slide to Word reports and Excel workbooks: the releases, the users, the risks."
nbText: """
All the posts, newest first, are in the [devlog](devlog/).
"""
nbSave
