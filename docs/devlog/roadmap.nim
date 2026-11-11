## devlog: 11 Nov 2026 D | Where xoffy is going | From one slide to Word reports and Excel workbooks: what the three formats share, the releases in the order they build on each other, who is waiting for each, the libraries next door, and what could go wrong.
## A dated post: the plan for xoffy as it was when 0.1 was written. Not updated afterwards (typos
## and links are fixed); where the plan changes, a new post says so.
import std/[os, strutils]
import nimib
import tabelline, tabelline/[nimib, pptx]
import xoffy
import ../blocks, ../slides

let docs = currentSourcePath().parentDir.parentDir
nbInit
nb.doc.filename = docs / "devlog" / "roadmap" / "index.html"
nb.useXoffy(title = "Where xoffy is going", homeHref = "../", backLabel = "Devlog",
            wordmarkHref = "../../")

nbTitle "11 November 2026", "Where xoffy is going", """
From one slide to Word reports and Excel workbooks: what the three formats share, the releases in
the order they build on each other, who is waiting for each, the libraries next door, and what
could go wrong.
"""

nbText: """
xoffy 0.1 writes a PowerPoint file from nothing: text, shapes, arrows, pictures and native tables,
on blank slides, in a file that passes the schemas of the standard and that LibreOffice opens
and draws ([Designing xoffy 0.1](../designing-0-1/)). Its first user, tabelline,
already sends its tables to slides ([What tabelline needs from xoffy](../tabelline-api/)).

That is a start, and a small one. The name promises Word and Excel too, and the people who make
tables and notebooks in Nim live in all three. This post is the plan to get there: bold in where
it goes, careful in the order.
"""

nbNote("""
A plan, not a promise. The order of the releases is the part that matters; what is inside each
one will move as the users ask for things. There are no dates.
""", nkWarning, "Read it as a plan")

nbText: """
## Three formats, one base

The reason one library can do all three is in [Everything you did not want to know about
pptx](../inside-pptx/): a .pptx, a .docx and a .xlsx are the same kind of thing. Each is a zip
of XML parts with a list of content types and files of relationships (the *package*, OPC), and
all three draw with the same language for colours, lines, text, shapes and pictures (DrawingML).
Only the top layer is their own: PresentationML for slides, WordprocessingML for documents,
SpreadsheetML for workbooks.

So the bottom of xoffy is already shared, and each new format costs only its top. Drawn with
xoffy itself, in the colours of what exists today:
"""

nbCode:
  let done = rgb"C8553D"
  let planned = rgb"FAF8F5"
  proc layer(text: string, x, y, w: Emu, filled: bool): Shape =
    shape(gRoundRect, box(x, y, w, 0.9.inch), (if filled: done else: planned), text,
          Font(size: 20, color: (if filled: rgb"FFFFFF" else: rgb"1F1E1D")))
  var stack = slide(
    textBox(markdown("**xoffy**, layer by layer", Font(size: 32)), box(0.8.inch, 0.4.inch, 11.inch, 0.8.inch)),
    layer("PresentationML: slides", 0.8.inch, 1.6.inch, 3.7.inch, true),
    layer("SpreadsheetML: sheets", 4.8.inch, 1.6.inch, 3.7.inch, false),
    layer("WordprocessingML: pages", 8.8.inch, 1.6.inch, 3.7.inch, false),
    layer("charts (DrawingML charts)", 0.8.inch, 2.8.inch, 11.7.inch, false),
    layer("DrawingML: colours, lines, text, shapes, pictures, tables", 0.8.inch, 4.0.inch, 11.7.inch, true),
    layer("the package (OPC): parts, content types, relationships", 0.8.inch, 5.2.inch, 11.7.inch, true),
    layer("zip, with zippy for deflate", 0.8.inch, 6.4.inch, 11.7.inch, true))
  for s in stack.shapes.mitems:
    if s.kind == skShape and s.fill.hex == "FAF8F5": s.line = line(rgb"1F1E1D", 1.5.pt, dsDash)
  var layers = newPresentation()
  layers.add stack
nbSlides layers, "roadmap-layers", "In colour what 0.1 has, dashed what is to come"

nbNote("""
Each layer is a `gRoundRect` shape with its text in it; the dashed ones get their line after the
slide is made, by walking `stack.shapes`. A slide is a plain Nim value: a sequence of shapes you
can change until you save it.
""", nkCode)

nbText: """
Charts sit across the three formats on purpose: a chart is the same part (`c:chartSpace`) in a
slide, a sheet or a page, and that is what makes it the last big piece. Word's tables are the
exception that proves the rule: a table in a document is not DrawingML's `a:tbl` but
WordprocessingML's own `w:tbl`, so xoffy's `Grid` will need a second writer there.

## The releases

Each release is one step that the next one stands on:
"""

let releases = tableData:
  release: ["0.1", "0.2", "0.3", "0.4", "0.5", "1.0"]
  about: ["slides from nothing", "decks you already have", "Excel workbooks", "Word documents",
          "charts", "an API that stops moving"]
  who: ["tabelline's tables on slides", "a company template; nimib notebooks as decks",
          "tables and data frames as sheets", "reports from notebooks; tables in documents",
          "plots that stay editable", "everyone"]
  status: ["built", "next", "planned", "planned", "planned", "later"]
let plan = tabella(releases):
  tabHeader "The releases of xoffy", "in the order they build on each other"
  colsLabel:
    about: "what it is about"
    who: "who asks for it"
  tabStyle style.text(weight = "bold"), loc.body(cols = "status", rows = [0])
  optCssTheme()
nbTable plan
nbSlides toPresentation([plan]), "roadmap-releases", "The same table, sent to a slide by tabelline/pptx", small = true

nbText: """
### 0.2: decks you already have

0.1 only writes; 0.2 reads. The reason is the most common request anyone makes of a PowerPoint
library: *use our template*. A company template is a deck with masters, layouts and placeholders
(the boxes that say *Click to add title*); a slide that uses a layout fills its placeholders
instead of placing boxes by hand.

- **Open a deck**: `openPresentation("template.pptx")`, on the package reader that 0.1 already
  has. Keep every part xoffy does not understand, and write it back untouched.
- **Layouts and placeholders**: list the layouts of a template, make a slide from one, fill its
  title, body and picture placeholders by name.
- **Speaker notes**: the notes part of each slide, and its notes master.
- **Groups**, **SVG pictures** (with the PNG fallback PowerPoint asks for), **gradients** and
  **custom geometry**: what a diagram drawn elsewhere needs to arrive as shapes.
- **Checked in PowerPoint**, not only in LibreOffice and against the schemas (see the risks).

With 0.2, a nimib notebook can become a deck in the template of whoever asked for it, and
diagrammari's diagrams can arrive as shapes and arrows you move with the mouse, not as a picture.

### 0.3: Excel workbooks

A workbook is the format where tables live. It comes before Word because it is smaller, because
charts need it (next), and because two users are waiting:

- **Sheets and cells**: strings (in the shared string table Excel expects), numbers, booleans,
  dates (which in a workbook are numbers with a date format), formulas written as text.
- **Number formats and styles**: the `numFmt`, font, fill and border tables of `styles.xml`,
  deduplicated like the pictures of a deck.
- **Merged cells, column widths, frozen panes, a filter on the header row.**
- **Reading**: the values of a sheet, so a workbook can be data, not only output.

tabelline's tables go to a sheet with their formats as Excel number formats (so a number stays a
number), and nanuq's data frames go to and from a sheet.

### 0.4: Word documents

A document is a long flow of paragraphs, and the hardest of the three to get right, which is why
it comes after the two that are boxes on a grid.

- **Paragraphs and runs**, with the same `Font` and the same Markdown as a text box.
- **Styles**: headings, lists, quotes, code, from a `styles.xml` that a template can bring.
- **Tables** (`w:tbl`: the second writer for `Grid`), **pictures** inline, **sections** with page
  size, margins, headers and footers.
- **Opening a template**, as for decks in 0.2.

This is the release that gives a nimib page a `.docx` twin: the text, the code, the outputs, the
tables, in the styles of a report someone else designed.

### 0.5: charts

A chart in any of the three formats is a chart part (DrawingML charts, `c:` in the XML) and,
beside it, a small workbook with its data, so that PowerPoint and Word can open *Edit data*.
That workbook is why charts wait for 0.3. The plan is the common charts first: bars, lines,
points, areas and pies, with their axes, titles, legends and number formats.

### 1.0: an API that stops moving

1.0 is not more features; it is a promise. The names and types that 0.1 to 0.5 settle on stay,
and what xoffy writes is checked by PowerPoint, Word and Excel themselves, not only by the
schemas and LibreOffice.

### And after

Things that fit xoffy and are not planned: the OpenDocument formats (`.odp`, `.ods`, `.odt`,
LibreOffice's own; also XML in a zip, also an ISO standard), text extraction for search and for
diffing decks in a review, and the clipboard formats Office uses inside its own copy and paste.

## Who is waiting

A library is shaped by its users, and these are the ones in sight, all in Nim:
"""

let users = tableData:
  user: ["tabelline", "nimib", "diagrammari", "nanuq", "plans and Gantt charts"]
  wants: ["its tables as native tables: on slides (0.1), in sheets (0.3), in documents (0.4)",
          "a notebook as a deck in a template (0.2), as a report (0.4)",
          "diagrams as shapes and arrows you can edit (0.2: groups, connectors between shapes)",
          "data frames to and from a sheet (0.3)",
          "a timeline on a slide or a sheet, from tabelline's styles (0.1 today, 0.3)"]
nbTable tabella(users):
  tabHeader "Who is waiting for what"
  colsLabel:
    wants: "what it wants from xoffy"
  optCssTheme()

nbText: """
## The libraries next door

xoffy is not the first library to write Office files, and the good ones are worth reading
before writing each release. In other languages:
"""

let others = tableData:
  library: ["python-pptx", "python-docx", "openpyxl", "XlsxWriter", "officer", "PptxGenJS",
            "Apache POI", "Open XML SDK"]
  language: ["Python", "Python", "Python", "Python", "R", "JavaScript", "Java", ".NET"]
  formats: ["pptx", "docx", "xlsx", "xlsx", "docx, pptx", "pptx", "all three, and the old binary ones",
            "all three"]
  does: ["reads and writes", "reads and writes", "reads and writes", "writes", "reads and writes",
         "writes", "reads and writes", "reads and writes, close to the XML"]
nbTable tabella(others):
  tabHeader "Libraries in other languages"
  colsLabel:
    does: "what it does"
  optCssTheme()

nbText: """
Each one teaches something. python-pptx is the model for 0.2: it opens a template and keeps
what it does not understand. XlsxWriter, which only writes, is the model for 0.3's first half:
small and fast, with documentation that explains the Excel format as it goes. officer, with its
companion flextable, is how many R users put tables in Word and PowerPoint, which is the job of
tabelline/pptx too.

And in Nim, as far as a search of GitHub goes in November 2026:
"""

let nimOnes = tableData:
  library: ["ringabout/xlsx", "ringabout/docx", "mashingan/excelin", "khchen/xl",
            "mantielero/xlsxwriter.nim", "nimbase/opendocs"]
  does: ["reads xlsx", "reads the plain text of a docx", "creates and reads xlsx",
         "creates, reads and changes xlsx", "writes xlsx, by binding the C library libxlsxwriter",
         "reads and writes docx and PDF, reads xlsx; pptx on its list"]
nbTable tabella(nimOnes):
  tabHeader "Libraries in Nim"
  colsLabel:
    does: "what it does"
  optCssTheme()

nbText: """
None of them writes PowerPoint today, which is where xoffy started. For Excel and Word, the
first step of 0.3 and 0.4 is to read these closely: what they got right, where their APIs feel
like Nim, and whether xoffy should depend on one of them instead of writing its own. The answer
may well be yes; a smaller xoffy is a better xoffy.

## What could go wrong

Being bold in the plan means being honest about its risks:

- **PowerPoint has not opened a file of xoffy yet.** Every deck so far was checked against the
  schemas of the standard, read back by python-pptx, and drawn by LibreOffice; none was opened
  by PowerPoint itself, which is stricter than all three in places nobody documents. This is
  the first thing to fix, before 0.2: open every deck of these pages in PowerPoint, and keep a
  record of what it says.
- **Text cannot be measured.** xoffy does not know how wide a line of text is, so it guesses
  column widths from the number of characters and leaves the rest to the application. Doing
  better means reading font files, which is a library of its own; the plan is to keep guessing
  well, and to let the application fit text where the format allows it.
- **Fonts are names.** A run asks for a font by name and the computer that opens the file
  decides; the slides on these pages show it every time Jost falls back to another font. Fonts
  can be embedded in a deck, and that may become a feature.
- **The standard is large.** ECMA-376 is thousands of pages, and PowerPoint, Word and Excel
  each write things beyond it. The defence is the one 0.1 uses: write the smallest XML that
  does the job, check it against the schemas, and test in the applications.
- **Too many dependencies.** Today xoffy needs the standard library and zippy. The plan is to
  stay there: a new dependency has to save a release's worth of work.

## What does not change

Whatever moves in the plan, these stay as 0.1 set them:

- **Native, not pictures.** A table is a table, a shape a shape, text is text: everything
  xoffy writes can be edited in the application that opens it.
- **Plain Nim values.** A slide, a grid, a workbook are objects you build and change; a writer
  turns them into XML at the end, and nothing is hidden in between.
- **The same input, the same bytes.** No dates, no random ids: a file can be compared, cached
  and kept in git.
- **Checked against the standard.** Every file the tests and the pages write passes the schemas
  of ECMA-376.
- **From the simplest up.** Each new piece is explained on these pages, from zero, in the order
  it is built, as this devlog did for 0.1.
"""
nbSave
