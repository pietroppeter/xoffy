## devlog: 11 Nov 2026 B | Designing xoffy 0.1 | What the first version of xoffy does, built from the zip up: lengths, the box, the package, DrawingML's colours, lines, text and tables, and the presentation that puts them on slides. Each layer with its code and the slide it makes, and how it is all checked.
## A dated post: the design of xoffy 0.1, written as it was built. Not updated afterwards (typos and
## links are fixed); what changes later goes in a later post.
import std/[os, strutils, sequtils, tables, algorithm]
import nimib
import tabelline, tabelline/nimib
import xoffy, xoffy/[zip, opc, xml]
import ../blocks, ../slides

let docs = currentSourcePath().parentDir.parentDir
let root = docs.parentDir
nbInit
nb.doc.filename = docs / "devlog" / "designing-0-1" / "index.html"
nb.useXoffy(title = "Designing xoffy 0.1", homeHref = "../", backLabel = "Devlog", wordmarkHref = "../../")

nbTitle "11 November 2026", "Designing xoffy 0.1", """
What the first version of xoffy does, built from the zip up: lengths, the box, the package,
DrawingML's colours, lines, text and tables, and the presentation that puts them on slides. Each
layer with its code and the slide it makes, and how it is all checked.
"""

nbText: """
xoffy started from an experiment in tabelline ([#57](https://github.com/pietroppeter/tabelline/pull/57)):
one file of about 900 lines that turned a table into a PowerPoint slide, with its own zip, its own
DrawingML and its own package, all as strings. It worked, and it showed that everything except the
table belonged somewhere else: any Nim program that wants a slide needs the zip, the package and
the slide, and so will Word and Excel. That somewhere else is xoffy.

0.1 is PowerPoint only, and only writing. It is built in layers, each a module that needs only the
ones under it, and this post climbs them in order. The [previous post](../inside-pptx/) explains
the format itself; here is how xoffy writes it.
"""

nbNote("""
Green cards like this one are about the code. Every block of code on this page ran when the page
was built, in this order; the slides under them are what LibreOffice drew of the files they wrote.
""", nkCode, "Reading the code")

nbToc()

nbText: """
## The layers

| module | what it is | needs |
|---|---|---|
| `xoffy/units` | lengths: `Emu`, and `inch`, `cm`, `mm`, `pt`, `px` | nothing |
| `xoffy/xml` | writing XML: `esc`, `tag`, `attrs` | nothing |
| `xoffy/zip` | the box: `writeZip`, `readZip` | zippy (deflate, inflate) |
| `xoffy/opc` | the package: parts, content types, relationships | zip, xml |
| `xoffy/drawingml` | colours, lines, text, shapes' geometry, tables | units, xml |
| `xoffy/images` | the format and size of a PNG, JPEG or GIF; a PNG from Nim | zip |
| `xoffy/pptx` | the presentation: slides, shapes, theme, master, layout | all of the above |

`import xoffy` gives `units`, `drawingml`, `images` and `pptx`, what a deck needs; `zip`, `opc`
and `xml` are imported on their own, by whoever reads files or writes a format xoffy does not.

## Lengths

Office measures in EMU, 914,400 to the inch. xoffy keeps every length as an `Emu`, a distinct
integer, so a number of points can never be passed where EMU are expected, and gives a
constructor for each unit:
"""
nbCode:
  echo 1.inch, " ", 2.54.cm, " ", 72.pt, " ", 96.px   # all the same length
  echo 13.333.inch.toCm, " cm"
  echo 1.inch / 2 + 1.cm

nbText: """
## The box

A .pptx is a zip. Nim's standard library has none, and the obvious package,
[zippy](https://github.com/guzba/zippy), writes zips with ZIP64 records in every entry, in the
reverse of the order given and stamped with today's date. Office opens ZIP64, but it is not needed
below 4 GB, and the date and order make every build of the same deck different. So xoffy writes
the zip itself, about a hundred lines, and takes from zippy only what is hard: deflate and inflate.
"""
nbCode:
  let z = writeZip([("hello.txt", "Hello, Office! ".repeat(20)), ("empty", "")])
  echo z.len, " bytes, starting with ", z[0 .. 3].escape
  for name, data in readZip(z): echo name, ": ", data.len, " bytes"
  echo writeZip([("a", "1")]) == writeZip([("a", "1")])   # the same entries, the same bytes

nbNote("""
`writeZip` writes, for each entry, a local header and the data (deflated when that makes it
smaller), then the central directory and its end record; the date is 1 January 1980, the first
day zip can say. `readZip` starts from the end record, as every reader does, and checks each
entry's CRC-32. Names that are not ASCII get the UTF-8 flag, so `è.txt` stays `è.txt`.
""", nkCode)

nbText: """
## The package

The parts of an Office file, their content types and the relationships between them are a
`Package`: a list of parts (name, content type, bytes) and, for each part, its relationships.
`relate` adds one and returns its id; the same target twice gets the same id; targets are written
relative to the source's folder, as the standard wants. `toZip` writes `[Content_Types].xml` and
every `.rels` from them:
"""
nbCode:
  var p = Package()
  p.add "ppt/presentation.xml", "application/vnd.example+xml", "<presentation/>"
  p.add "ppt/media/image1.png", "image/png", solidPng(2, 2, (0, 0, 0))
  echo p.relate("", "ppt/presentation.xml", relOfficeDocument)
  echo p.relate("ppt/presentation.xml", "ppt/media/image1.png", relImage)
  echo p.relationsOf("ppt/presentation.xml")[0].target
  let back = readPackage(p.toZip)
  echo back.mainPart, ", ", back.parts.len, " parts"
nbXmlText p.contentTypesXml, "[Content_Types].xml, from the parts", open = true

nbText: """
`readPackage` is the way back, and 0.1 already has it: the tests use it to check every deck, and
the next version will use it to open decks made by someone else.

## DrawingML

DrawingML is the drawing language the three formats share, and the largest module. Its values
are plain Nim objects; every field has a default that means *inherit* (from the theme, the master,
the application), so a value says only what it changes, and the XML leaves the rest out.

### Colours and lines

A `Color` is a hex value, one of the theme's colours, or none. `inherit` writes nothing; `noColor`
writes `<a:noFill/>`, which is not the same thing:
"""
nbCode:
  echo colorXml(rgb"C8553D")
  echo colorXml(scheme(accent1))
  echo fillXml(rgb"000000".withAlpha(0.25))
  echo fillXml(noColor), " vs [", fillXml(inherit), "]"
  echo lineXml(line(rgb"1F1E1D", 2.pt, dsDash, tail = ahTriangle))

nbText: """
### Text: runs, paragraphs, frames

Text is the part every Office format has, and it nests: a **run** is text in one `Font`; a
**paragraph** is runs, aligned, maybe with a bullet; a **frame** is paragraphs in a box, with its
insets, its anchor (top, middle, bottom) and whether it wraps. `frame("...")` makes one paragraph
per line; `markdown("...")` reads a little Markdown, because that is how nimib users already write
text: `**bold**`, `*italic*`, `` `code` ``, `^super^`, `~sub~`, `~~strike~~`, `[links](...)`, and
lines starting with `- ` or `1. ` as bulleted or numbered paragraphs.
"""
nbCode:
  let words = markdown("""**Bold**, *italic*, `code`, ~~strike~~, H~2~O and E = mc^2^, [a link](https://nim-lang.org)
- a bullet
  - a bullet inside it
1. a number
2. another""", Font(size: 32))
  for p in words.paragraphs[0 .. 1]: echo p.runs.mapIt((if it.font.bold: "b:" elif it.font.italic: "i:" else: "") & it.text)
  var text = slide(textBox(words, box(0.6.inch, 0.4.inch, 8.5.inch, 4.5.inch)))
  text.add textBox(frame("left\ncentre\nright", Font(size: 32)), box(9.inch, 0.4.inch, 3.8.inch, 2.inch))
  text.shapes[^1].text.paragraphs[1].align = taCenter
  text.shapes[^1].text.paragraphs[2].align = taRight
  text.add textBox(frame("Jost, 40 pt, in the theme's second accent",
                         Font(size: 40, typeface: "Jost", color: scheme(accent2))),
                   box(0.8.inch, 5.inch, 12.inch, 1.5.inch))
  var textDeck = newPresentation()
  textDeck.add text
nbSlides textDeck, "design-text", "The machine that drew this has no Jost, so LibreOffice picked another font: a run names its font, and the computer that opens the file decides"

nbNote("""
`markdown` turns each line into a `Paragraph` of `Run`s: the bullets are `Bullet` values, the
levels come from the indentation (two spaces per level). A run keeps its URL in `link`; the
presentation turns it into a hyperlink relationship of the slide when it writes the XML (DrawingML
does not know where it is written, so it asks the writer for an id through a callback,
`LinkSink`).
""", nkCode)

nbText: """
### Shapes

Office has 187 preset shapes, each drawn from formulas by the application: xoffy names 48 of
them in `Geometry` (the rest are a line in the enum away) and only says which one, where, and how
it is filled and outlined. Here are twenty-four, in the theme's colours and in a few of our own:
"""
nbCode:
  var gallery = slide()
  let kinds = [gRect, gRoundRect, gEllipse, gTriangle, gDiamond, gPentagon, gHexagon, gOctagon,
               gParallelogram, gTrapezoid, gStar5, gStar8, gPlus, gHeart, gCloud, gDonut,
               gCan, gCube, gRightArrow, gChevron, gHomePlate, gCallout, gLightning, gMoon]
  let fills = [scheme(accent1), scheme(accent2), scheme(accent5), scheme(accent6),
               rgb"C8553D", rgb"2E5EAA", rgb"F2B134", rgb"2F8F5B"]
  for k, g in kinds:
    let (col, row) = (k mod 8, k div 8)
    let b = box(0.45.inch + 1.6.inch * col, 0.5.inch + 2.3.inch * row, 1.3.inch, 1.3.inch)
    gallery.add shape(g, b, fills[k mod fills.len])
    gallery.add textBox(frame($g, Font(size: 14), taCenter),
                        box(b.x - 0.15.inch, b.y + 1.4.inch, 1.6.inch, 0.4.inch))
  var galleryDeck = newPresentation()
  galleryDeck.add gallery
nbSlides galleryDeck, "design-shapes"

nbText: """
A `Box` is where a shape is: its top left corner, its size, its rotation, and whether it is
flipped. A **connector** goes from one point to another; when it goes up or left, xoffy flips its
box, as PowerPoint does. Arrows are the line's `head` and `tail`.

### Tables

A DrawingML table is a `Grid`: the column widths, then rows of cells. Each `GridCell` has a frame
of text, a fill, four borders (`edLeft`, `edRight`, `edTop`, `edBottom`), margins and an anchor.
`merge` makes a cell span others, and marks the ones it covers, which stay in the grid. A grid
with no table style says *no line* on every side it leaves empty, because PowerPoint and
LibreOffice draw different things for a cell that says nothing.
"""
nbCode:
  var grid = newGrid(@[@["", "2025", "2026"], @["", "H1", "H2"], @["slides", "12", "40"],
                       @["documents", "3", "9"], @["sheets", "0", "5"]], colWidth = 3.4.inch,
                     rowHeight = 0.8.inch, font = Font(size: 32))
  grid.merge(0, 0, 1, 0)
  grid.merge(0, 1, 0, 2)
  grid[0, 1].text = frame("files written", Font(size: 32, bold: true), taCenter)
  grid[0, 0].text = frame("format", Font(size: 32, bold: true))
  grid[0, 0].anchor = anBottom
  for c in 1 .. 2: grid[1, c].text.paragraphs[0].align = taCenter
  for r in 2 .. 4:
    for c in 1 .. 2: grid[r, c].text.paragraphs[0].align = taRight
  grid.setBorders(line(rgb"1F1E1D", 0.75.pt), {edBottom})
  for c in 0 .. 2: grid[1, c].borders[edBottom] = line(rgb"1F1E1D", 2.pt)
  for r in [2, 4]:
    for c in 0 .. 2: grid[r, c].fill = rgb"F1E4DC"
  var tableDeck = newPresentation()
  tableDeck.add slide(tableFrame(grid, 1.6.inch, 1.6.inch))
nbSlides tableDeck, "design-table"

nbText: """
This is the piece tabelline needs, and the [next post](../tabelline-api/) is about how it uses it.

## The presentation

A `Presentation` is a size, a list of slides and a `Theme`. A `Slide` is a list of shapes and
maybe a background. The shapes are values made by functions: `textBox`, `shape`, `connector`,
`picture` (from bytes or a file; give its width or its height and the other keeps the
proportions), `tableFrame`. Building a deck is building values:
"""
nbCode:
  var deck = newPresentation(title = "Two slides", author = "xoffy")
  deck.add slide(textBox("One", box(1.inch, 1.inch, 6.inch, 2.inch), Font(size: 96, bold: true)))
  deck.add slide(rgb"2E5EAA",
    textBox("Two", box(1.inch, 1.inch, 6.inch, 2.inch), Font(size: 96, bold: true, color: rgb"FFFFFF")),
    picture(png(90, 60, proc (x, y: int): (int, int, int) = (250 - x, 180 + y, 60)), 8.inch, 1.inch, h = 4.inch))
nbSlides deck, "design-two", small = true

nbText: """
`toPackage` writes everything a presentation needs around its slides: the properties
(`docProps/core.xml`, `docProps/app.xml`), the presentation part, one master, one Blank layout,
the theme, and for each slide its part and its relationships (to the layout, its pictures, its
links). A picture used on many slides is stored once. Here is the second slide's XML:
"""
nbXml deck, "ppt/slides/slide2.xml", "the second slide"

nbText: """
### Themes

The theme gives the twelve colours and two fonts that `scheme(...)` and inherited text use. The
default is Office's own; any `Theme` value can replace it, and every shape that says
`scheme(accent1)` follows:
"""
nbCode:
  proc swatches(t: Theme): Presentation =
    result = newPresentation(theme = t)
    var s = slide(textBox(t.name & ": " & t.headingFont & " and " & t.bodyFont,
                          box(0.6.inch, 0.4.inch, 12.inch, 1.inch), Font(size: 32, typeface: "+mj-lt")))
    for k, c in [accent1, accent2, accent3, accent4, accent5, accent6]:
      s.add shape(gEllipse, box(0.6.inch + 2.1.inch * k, 2.inch, 1.8.inch, 1.8.inch), scheme(c),
                  $c, Font(size: 16, color: scheme(bg1)))
    result.add s
  var ufficio = officeTheme
  ufficio.name = "Ufficio"
  ufficio.accents = ["C8553D", "2E5EAA", "2F8F5B", "F2B134", "7A5C99", "5C5B57"]
  ufficio.headingFont = "Jost"
  ufficio.bodyFont = "Jost"
nbSlides swatches(officeTheme), "design-theme-office", small = true
nbSlides swatches(ufficio), "design-theme-ufficio", "Jost again falls back to another font here", small = true

nbNote("""
`+mj-lt` is how DrawingML says *the theme's heading font* (`+mn-lt` is the body font): a run in
it changes with the theme, like a `scheme` colour. The theme's part is written from the `Theme`
value by `themeXml`, with the three fills, lines and effects the schema requires.
""", nkCode)

nbText: """
## How it is checked

Every layer has its tests (`nim r tests/all.nim`): lengths, XML escaping, the zip both ways (and
that the same entries give the same bytes), relative targets, content types, colours, lines,
runs, Markdown, merged cells, picture sizes, and whole decks read back with `readPackage`: the
parts PowerPoint expects, every XML part well formed, the slide list, the links as external
relationships, a picture stored once, the same deck giving the same bytes.

Then every deck on these pages goes through LibreOffice when the page is built; a deck it could
not open would show no slides. And while writing 0.1, the decks were checked against the XML
schemas of the standard (ISO/IEC 29500, Transitional) and a few rules PowerPoint adds: they found
one mistake (an empty `p:normalViewPr`, which the schema does not allow) and now pass.

What has not checked them yet is PowerPoint. That is the first thing 0.1 needs from a person with
a Mac or a PC.

## What is not in 0.1

- **Reading and editing decks**: opening a template, its layouts and placeholders, adding slides
  to it. The package reader is there; the presentation reader is not.
- **Speaker notes**, groups of shapes, gradients, shadows, custom geometry, SVG pictures, charts,
  animations, slide transitions.
- **Measuring text.** xoffy does not know how wide a line is, so it cannot make a box fit its
  text; `afResize` asks the application to do it when the file is opened.
- **Word and Excel.** The [roadmap](../roadmap/) says when.

## How it is built

From scratch, the whole library is these files:
"""

var files, whats: seq[string]
var counts: seq[int]
for f in ["src/xoffy.nim", "src/xoffy/units.nim", "src/xoffy/xml.nim", "src/xoffy/zip.nim", "src/xoffy/opc.nim",
          "src/xoffy/drawingml.nim", "src/xoffy/images.nim", "src/xoffy/pptx.nim",
          "tests/test_core.nim", "tests/test_drawingml.nim", "tests/test_pptx.nim"]:
  files.add f
  counts.add readFile(root / f).splitLines.len
  let first = readFile(root / f).splitLines[0]
  whats.add(if first.startsWith("## "): first[3 .. ^1].strip(chars = {'.', ' '}) else: "tests")
let built = tableData:
  file: files
  what: whats
  lines: counts
nbTable tabella(built):
  tabHeader "xoffy 0.1", "every file, counted when this page was built"
  grandSummaryRows:
    total: agg.sum
  fmtInteger "lines"
  optCssTheme()

nbText: """
The order to read them in is the order of this post: `units` and `xml` (each a page), `zip` (the
box, and the only place zippy is called), `opc` (parts and relationships), `drawingml` (the
values, then their XML, from colours to tables), `images`, and `pptx`, whose `toPackage` is the
one function that knows what a presentation is made of. Every writer is a function from a Nim
value to a string of XML; nothing is kept between calls, except the package that collects the
parts.

A few choices, and why:

- **Values, not a document object.** A slide is a `seq[Shape]`, a shape an object with defaults:
  you build them as you build any Nim data, and the XML is written once, at the end. Reading
  and editing decks (0.2) will need a model that keeps what it does not understand; that will be
  a separate layer, not a change to this one.
- **Strings, not `std/xmltree`.** The writers concatenate strings with `tag` and `esc`. xmltree
  would build a tree only to print it, and its printer indents, which changes text.
- **Default means inherit.** Every field's zero value is *say nothing*, so the XML is as short as
  Office's own and the theme stays in charge.
- **Names that live beside tabelline's.** `TextAlign`, `Edge`, `GridRow`, `GridCell` and
  `markdown` were chosen so that `import tabelline, xoffy` has no clashes.
"""
nbSave
