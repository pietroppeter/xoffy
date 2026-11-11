## devlog: 11 Nov 2026 C | What tabelline needs from xoffy | xoffy's first user is tabelline: a table made for a web page, put on a slide as a native PowerPoint table. How a table becomes a grid of cells, what each part and each style maps to, the API it uses today, a Gantt chart that goes to a slide, and what tabelline will ask of xoffy next.
## A dated post: how tabelline/pptx uses xoffy 0.1, and what it needs next. Not updated afterwards
## (typos and links are fixed).
import std/[os, strutils, sequtils, sugar, tables, times]
import nimib
import tabelline, tabelline/[nimib, datasets, pptx]
import xoffy
import ../blocks, ../slides

let docs = currentSourcePath().parentDir.parentDir
nbInit
nb.doc.filename = docs / "devlog" / "tabelline-api" / "index.html"
nb.useXoffy(title = "What tabelline needs from xoffy", homeHref = "../", backLabel = "Devlog",
            wordmarkHref = "../../")

nbTitle "11 November 2026", "What tabelline needs from xoffy", """
xoffy's first user is [tabelline](https://github.com/pietroppeter/tabelline): a table made for a web
page, put on a slide as a native PowerPoint table. How a table becomes a grid of cells, what each
part and each style maps to, the API it uses today, a Gantt chart that goes to a slide, and what
tabelline will ask of xoffy next.
"""

nbText: """
tabelline makes display tables in Nim, after R's gt and Python's Great Tables: a header, a stub,
row groups, spanners, formatted numbers, colours and notes, rendered to HTML. People who make
tables for a living put them in slides and reports, so the next question was always going to be:
*can I have it in PowerPoint?* Not as a picture, but as a table PowerPoint can edit.

The answer started as an experiment inside tabelline
([#57](https://github.com/pietroppeter/tabelline/pull/57)), and is now `tabelline/pptx` on top of
xoffy. This post is the contract between the two: what tabelline asks, what xoffy gives, and what
is missing.
"""

nbNote("""
Green cards like this one are about the code. Every block of code on this page ran when the page
was built, in this order; the slides under them are what LibreOffice drew of the files they wrote.
The tables were made by tabelline, and the slides by tabelline and xoffy together.
""", nkCode, "Reading the code")

nbToc()

nbText: """
## The simplest table, on a slide

A table of three planets, and the one call that puts it on a slide:
"""
nbCode:
  let small = tableData:
    planet: ["Mercury", "Venus", "Earth"]
    moons: [0, 0, 1]
  let t = tabella(small):
    tabHeader "Three planets"
  t.savePptx "three-planets.pptx"
nbTable t
nbSlides toPresentation([t]), "tabelline-simplest", small = true

nbText: """
On the web page the table is HTML and CSS; on the slide it is a PowerPoint table with the same
rows, the same rules and the same text. In between, `savePptx` does three things:

1. **build**: the step every renderer of tabelline shares, which formats the values, places the
   footnote marks, sorts the rows into their groups and works out the styles of every cell;
2. **grid**: turns the built table into rows of cells, each with one *look* (its font, colour,
   fill, borders, padding, alignment), merged where a label spans;
3. **xoffy**: turns that grid into xoffy's `Grid`, puts it on a slide in the middle, and writes the
   presentation.

Only the last step is new. The first is tabelline's, the second is tabelline's view of a table as
cells, and the third is the line between the two libraries.

## A table is a grid of cells

xoffy knows nothing about titles, stubs or spanners. It knows a `Grid`: column widths, and rows of
`GridCell`s, each with a frame of text, a fill, four borders, margins, an anchor, and how many
columns and rows it spans. So every part of a tabelline table has to become cells:
"""

let parts = tableData:
  part: ["title, subtitle", "spanner", "stubhead, a column label beside a spanner", "column label",
         "row group", "stub, body cell", "footnote, source note"]
  becomes: ["a row of one cell, spanning every column", "a cell spanning its columns",
            "a cell spanning down, over the spanner's rows", "a cell",
            "a row of one cell, spanning every column", "a cell", "a row of one cell, spanning every column"]
  xoffy: ["`span = ncols`, the others `hMerge`", "`span = n`", "`rowSpan = levels + 1`, below `vMerge`",
          "`GridCell`", "`span = ncols`", "`GridCell`", "`span = ncols`"]
nbTable tabella(parts):
  tabHeader "Parts to cells"
  fmtMarkdown "xoffy"
  optCssTheme()

nbText: """
The look of each cell comes in two layers, the same as in HTML: first the table's options
(`tableFontSize`, `headingBackgroundColor`, `rowGroupBorderColor`, about forty of them), then the
CSS that `tabStyle` and `dataColor` put on that cell, read one declaration at a time. A slide has
no CSS, so each declaration becomes a field of xoffy:
"""

let css = tableData:
  css: ["color", "background-color", "font-size", "font-weight", "font-style", "font-family",
        "text-decoration", "text-transform: uppercase", "text-align", "vertical-align",
        "border-top (and the other sides)", "padding", "<a href>", "<sup>, <sub>"]
  xoffy: ["`Font.color`", "`GridCell.fill`", "`Font.size`, in points", "`Font.bold`", "`Font.italic`",
          "`Font.typeface`, the first real font of the list", "`Font.underline`, `Font.strike`",
          "`Font.caps`", "`Paragraph.align`", "`GridCell.anchor`",
          "`GridCell.borders[edTop]`: a `Line` with width, colour, dash", "`GridCell.margins`",
          "`Run.link`, a hyperlink of the slide", "`Font.baseline`, 30 or -25"]
nbTable tabella(css):
  tabHeader "CSS to DrawingML", "what tabelline reads, and where xoffy keeps it"
  fmtMarkdown "xoffy"
  optCssTheme()

nbText: """
A cell's text is HTML (`build` renders Markdown and formats to it), so a small reader turns
`<b>`, `<i>`, `<sup>`, `<sub>`, `<code>`, `<a>` and coloured `<span>`s into xoffy `Run`s, and a
`<br>` into a new `Paragraph`. Here is the heart of it, the function that makes one xoffy cell:
"""
nbFoldCode "deps/tabelline/src/tabelline/pptx.nim", start = "proc toGridCell", stop = "proc toGrid*",
           title = "tabelline/pptx.nim: toGridCell"

nbText: """
## Every part, on a slide

The table of tabelline's home page, and a table with every part, go through the same steps.
Footnote marks are raised runs, the stubhead and the moons column span down beside the spanner,
the colours of `dataColor` are fills:
"""
nbCode:
  let home = tabella(planets(), rownameCol = "planet", groupnameCol = "type"):
    tabHeader md("The **planets**"), "of the Solar System"
    colsHide ["density", "gravity", "day_length", "distance", "orbital_period", "rings"]
    colsLabel:
      mass: md("mass<br>10^24^ kg")
      diameter: md("diameter<br>km")
      mean_temp: md("mean<br>°C")
    fmtNumber "mass", decimals = 3, dropTrailingZeros = true
    fmtInteger "diameter"
    dataColor "mean_temp", palette = palette("rdbu"), domain = (-200.0, 200.0)
    tabSourceNote md("[NASA Planetary Fact Sheet](https://nssdc.gsfc.nasa.gov/planetary/factsheet/)")
  let everything = tabella(planets(), rownameCol = "planet", groupnameCol = "type"):
    tabHeader "Table header: title", "and subtitle"
    tabStubhead "stub head"
    tabSpanner "Size", ["diameter", "mass"]
    colsHide ["density", "gravity", "day_length", "orbital_period", "mean_temp", "rings"]
    fmtNumber "mass", decimals = 2
    fmtInteger "diameter"
    fmtNumber "distance", decimals = 1
    tabFootnote "The biggest of them all.", loc.body(cols = "mass", rows = [4])
    tabFootnote "In millions of km.", loc.columnLabels("distance")
    tabStyle style.text(weight = "bold", color = "#C8553D"), loc.body(cols = "moons", rows = [5])
    tabSourceNote "NASA Planetary Fact Sheet"
    optStylize 2, "cyan"
nbSlides toPresentation([home, everything]), "tabelline-planets", small = true

nbText: """
## A table on a slide of your own

`savePptx` makes a deck with one table per slide. To put a table on a slide with other things, ask
for the grid alone with `toGrid` (`maxWidth`, in points, scales it down to fit) and place it with
xoffy like any shape:
"""
nbCode:
  let g = home.toGrid(maxWidth = 420)
  var s = slide(
    textBox(markdown("**Four of them are giants**", Font(size: 40)), box(0.6.inch, 0.5.inch, 12.inch, 1.inch)),
    textBox(markdown("""- Jupiter alone is more than twice all the others together
- Venus is hotter than Mercury, though farther from the Sun
- the cold of the ice giants: about -200 °C""", Font(size: 22)), box(0.6.inch, 1.8.inch, 5.8.inch, 4.inch)),
    tableFrame(g, 6.8.inch, 1.4.inch))
  var mine = newPresentation()
  mine.add s
nbSlides mine, "tabelline-own-slide"

nbText: """
## A Gantt chart, on a slide

A harder table: a project plan as a Gantt chart, one column per week, a filled cell for each week
of an activity, a spanner for each month, a dashed line for today. It was a prototype for
tabelline's HTML (the project is invented: a garden on the Moon); here it is again, short, and
sent to a slide.
"""
nbCode:
  type Activity = tuple[stream, activity: string, first, last: int]
  let plan: seq[Activity] = @[
    ("Seeds", "Pick hardy varieties", 14, 22), ("Seeds", "Germination trials", 18, 30),
    ("Habitat", "Greenhouse dome", 15, 24), ("Habitat", "Soil from regolith", 20, 36),
    ("Rover", "Rover chassis", 16, 26), ("Rover", "Planting arm", 22, 33),
    ("Crew", "Gardener training", 19, 39)]
  const year = 2031
  let weeks = toSeq(14 .. 39)
  func wk(w: int): string = "W" & $w
  proc monthOf(w: int): string =
    let jan4 = dateTime(year, mJan, 4, zone = utc())
    ($(jan4 - days(ord(jan4.weekday)) + weeks(w - 1) + days(3)).month)[0 .. 2].toUpperAscii
  var columns: seq[(string, seq[Value])] = @[("stream", plan.mapIt(toValue(it.stream))),
                                             ("activity", plan.mapIt(toValue(it.activity)))]
  for w in weeks: columns.add (wk(w), plan.mapIt(toValue(0)))
  var gantt = tabella(toTableData(columns), rownameCol = "activity", groupnameCol = "stream"):
    tabHeader "A garden on the Moon", "weeks 14 to 39 of 2031, today is week 27"
    fmt cols(weeks.mapIt(wk(it))), (v: Value) => ""
    colsLabelWith cols(weeks.mapIt(wk(it))), (s: string) => s[1 .. ^1]
    tabOptions(tableFontSize = "13px", dataRowPadding = "3px", dataRowPaddingHorizontal = "0px",
               columnLabelsFontSize = "70%")
  for m in weeks.mapIt(monthOf(it)).deduplicate:
    gantt = gantt.tabSpanner(m, cols(weeks.filterIt(monthOf(it) == m).mapIt(wk(it))))
  let colours = {"Seeds": (47, 143, 91), "Habitat": (200, 85, 61), "Rover": (242, 177, 52),
                 "Crew": (46, 94, 170)}.toTable
  for i, a in plan:
    for w in a.first .. a.last:
      let (r, g, b) = colours[a.stream]
      let fill = "rgba(" & $r & ", " & $g & ", " & $b & ", " & (if w < 27: "1" else: "0.4") & ")"
      gantt = gantt.tabStyle(style.fill(fill), loc.body(cols(wk(w)), rows = i))
  gantt = gantt.tabStyle(style.borders({sLeft}, color = "#1F1E1D", style = "dashed", weight = "2px"),
                         loc.body(cols(wk(27))), loc.columnLabels(cols(wk(27))))
  gantt = gantt.tabSourceNote(md("**This week**: the first seeds sprouted; the dome design is signed off."))
nbTable gantt
nbSlides toPresentation([gantt]), "tabelline-gantt"

nbNote("""
The weeks are 26 columns of zeros whose text is hidden (`fmt` with a function that returns ""),
and the bars are fills: `tabStyle(style.fill(...), loc.body(...))` on each cell of each activity,
in full colour before today and 40% opaque after (`rgba`). On the slide the fill keeps its
alpha (`withAlpha`), and the dashed border of today is a `Line` with `dsDash`.
""", nkCode)

nbText: """
## What is lost on the way

A slide is not a page, and some of what a table says in CSS has nowhere to go:

- **CSS variables** (`optCssTheme`, which reads the page's colours): a slide has no page. A
  variable takes its fallback, or a value given in `PptxOptions(vars: ...)`.
- **`color-mix()`** is mixed in sRGB, not in the space it names: close, not equal.
- **Fonts** are names: the first real font of a CSS list is kept, and `system-ui` leaves the
  theme's font.
- **Widths** are estimated from the number of characters, because nothing measures text (see
  below). PowerPoint grows a row to fit its text, but not a column.
- **Lost**: the caption, `font-variant` (tabular figures), `letter-spacing`, `white-space`,
  widths in percent, pictures and nanoplots in cells.

## The API tabelline uses

Everything tabelline uses from xoffy fits in a few lines:

| what | xoffy |
|---|---|
| the table | `Grid`, `GridRow`, `GridCell`, `cell`, `frame` |
| text | `Paragraph`, `run`, `Font` (size, bold, italic, underline, strike, colour, typeface, baseline, caps) |
| colours | `rgb`, `withAlpha`, `noColor`, `inherit` |
| rules | `line`, `noLine`, `Dash`, `Edge` |
| placement | `TextAlign`, `Anchor`, `pt` |
| the deck | `newPresentation`, `slide`, `tableFrame`, `add`, `save`, `toPptx` |

and `tabelline/pptx` gives, on top of it:

- `toGrid(t, maxWidth)`: the table as a `Grid`;
- `toShape(t)`: the grid in a frame, in the middle of the slide;
- `toPresentation(tables)`, `toPptx(tables)`, `savePptx`: a deck, one table per slide;
- `toClipboardHtml(t)`: the same cells as HTML with every style inline, which PowerPoint and Word
  paste as a table of their own.

## What tabelline will need next

In order of how much a tabelline user would notice:

1. **Measuring text.** Column widths are guessed from the number of characters. xoffy could carry
   the widths of a few common fonts (the metric-compatible ones LibreOffice ships: Liberation for
   Arial and Times, Carlito for Calibri), so a column is as wide as its longest line, and a long
   table knows when it no longer fits a slide.
2. **A table in a deck of your own.** People have templates. Opening a .pptx, adding a slide from
   its *Title Only* layout, and placing the table under the title needs xoffy to read and edit
   decks: the main feature of xoffy 0.2.
3. **Long tables across slides.** With measured heights, tabelline can split a table into
   slides, repeating the column labels, as `gt` does across pages.
4. **Word.** A report is a document more often than a deck. A Word table (`w:tbl`) has the same
   cells, borders, fills and spans, with a different XML and some differences (a vertical merge
   is `vMerge="restart"` then `vMerge`; header rows can repeat on every page). The grid of
   tabelline should not need to change: xoffy should write the same `Grid` to Word.
5. **Excel.** In a spreadsheet a number must stay a number: tabelline knows each cell's value and
   its format, so `fmtNumber(decimals = 2)` should become the number format `#,##0.00` on a real
   number, not the text "1,234.00". That needs the values beside the text, and an Excel writer.
6. **Pictures in cells.** Nanoplots and images cannot go in a DrawingML cell; they can be shapes
   placed over the table, once xoffy knows where each cell ends up (measuring, again).
7. **The clipboard.** `toClipboardHtml` already pastes as a table; wrapping it for the system
   clipboard (`CF_HTML` on Windows, HTML on macOS) is xoffy's job, and PowerPoint's own clipboard
   format, a zip with a `graphicFrame` inside, would paste exactly.

The shape of it: one `Grid`, three writers. tabelline maps its table to a grid once, and xoffy
puts that grid on a slide, in a document or in a sheet. That is the plan in the
[roadmap](../roadmap/).
"""
nbSave
