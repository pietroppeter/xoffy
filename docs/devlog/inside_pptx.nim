## devlog: 11 Nov 2026 A | Everything you did not want to know about pptx | Where PowerPoint's files come from, the format war that made them an international standard, and what is inside one, from the zip to the last attribute: a package of parts, relationships between them, a theme, a master, a layout, and the slide, drawn in DrawingML.
## A dated post: the history of the Office file formats and the insides of a .pptx, told from a deck
## that xoffy writes. Not updated afterwards (typos and links are fixed).
import std/[os, strutils]
import nimib
import tabelline, tabelline/nimib
import xoffy, xoffy/[opc, zip]
import ../blocks, ../slides

let docs = currentSourcePath().parentDir.parentDir
nbInit
nb.doc.filename = docs / "devlog" / "inside-pptx" / "index.html"
nb.useXoffy(title = "Everything you did not want to know about pptx", homeHref = "../",
            backLabel = "Devlog", wordmarkHref = "../../")

nbTitle "11 November 2026", "Everything you did not want to know about pptx", """
Where PowerPoint's files come from, the format war that made them an international standard,
and what is inside one, from the zip to the last attribute: a package of parts, relationships
between them, a theme, a master, a layout, and the slide, drawn in DrawingML.
"""

nbText: """
xoffy writes .pptx files, so it has to know what one is. This post is what we learned, put in
order: first a short history (why there are two standards for office documents, and why the one
from Microsoft is called *open*), then the file itself, opened part by part. Everything inside is
shown from a deck xoffy writes while this page is built, so what you read is what the library
does today.
"""

nbNote("""
Green cards like this one are about the code: what xoffy does at that step, and why. The blocks of
code ran when the page was built; the slides under them are what LibreOffice drew of the file they
wrote.
""", nkCode, "Reading the code")

nbToc()

# ------------------------------------------------------------------------------------- history

nbText: """
## A short history

### Overheads, 1987

PowerPoint began as *Presenter*, a program for overhead transparencies designed by Robert Gaskins
and written by Dennis Austin (with Thomas Rudkin) at Forethought, a startup in Silicon Valley. The
name was taken, so a few weeks before release it became PowerPoint. Version 1.0 shipped for the
Macintosh on 20 April 1987, in black and white, to be printed on film for an overhead projector;
three months later Microsoft bought Forethought for about $14 million, its first significant
acquisition. The second version made 35 mm colour slides, sent by modem to an imaging centre and
returned by courier; only the third, in 1992, showed a presentation on a screen.
([PowerPoint's history](https://en.wikipedia.org/wiki/Microsoft_PowerPoint#History))

### Binary years, 1987 to 2007

For twenty years a presentation was a binary file. From 1.0 to 7.0 the format changed with every
version and was never documented. PowerPoint 97 settled on one `.ppt` format, built on the
*Compound File Binary Format*, a little file system inside a file (sectors, a table of where each
stream lives, directories of streams), the same container as `.doc` and `.xls`. It stayed the
default until 2007; Microsoft published its specification later, and it is still maintained,
because PowerPoint still opens and saves it.
([PowerPoint's file formats](https://en.wikipedia.org/wiki/Microsoft_PowerPoint#File_formats))

### XML, and the other office

XML reached Office in pieces: Excel's *SpreadsheetML* in Office XP (2000), Word's in 2002, both
in Office 2003. Each was one large XML file, not a package.
([Microsoft Office XML formats](https://en.wikipedia.org/wiki/Microsoft_Office_XML_formats))

Meanwhile, another office was growing in Germany. Marco Börries wrote *StarWriter* in 1985, for a
Z80; Star Division, in Lüneburg, grew it into StarOffice. Sun Microsystems bought it in 1999 for
$73.5 million, the story goes because that cost less than 42,000 licences of Microsoft Office,
and released its source in July 2000 as **OpenOffice.org**. Its XML file format went to a
technical committee of OASIS (first meeting December 2002), became the **OpenDocument Format**
(ODF) on 1 May 2005, and the international standard ISO/IEC 26300 in November 2006, after a
unanimous ballot.
([StarOffice](https://en.wikipedia.org/wiki/StarOffice),
[OpenOffice.org](https://en.wikipedia.org/wiki/OpenOffice.org),
[OpenDocument](https://en.wikipedia.org/wiki/OpenDocument#Standardization))

### The format war, 2005 to 2008

Governments started asking for open formats (the European Union had asked Microsoft to
standardise its Office 2003 XML), and ODF was an open format that Microsoft did not make. In
November 2005 Microsoft announced it would standardise its next formats through Ecma International
as **Office Open XML**. It gave Ecma about 2,000 pages; Ecma's committee TC45 turned them into
about 6,000, approved as ECMA-376 on 7 December 2006. Office 2007 made them its default: `.docx`,
`.xlsx`, `.pptx`, a zip of XML files.

Then ISO. ECMA-376 went through the *fast track*, and what followed has been called the most
controversial ballot ISO ever held: reports of vote buying, protests in Oslo and Bangalore,
national bodies that changed their votes. The first ballot, closed in September 2007, failed:
17 of 32 participating members approved, short of two thirds. In February 2008 a five-day meeting
in Geneva had 1,027 comments to resolve and 873 proposed changes, and discussed about a fifth of
them; the rest were voted in a block. On 2 April 2008 the revised text passed, with 75% of the
participating members. South Africa, Brazil, India and Venezuela appealed, and lost. ISO/IEC
29500 was published in November 2008.
([Office Open XML](https://en.wikipedia.org/wiki/Office_Open_XML),
[its standardization](https://en.wikipedia.org/wiki/Standardization_of_Office_Open_XML))

### Strict, Transitional, and what everyone writes

ISO/IEC 29500 has two flavours. **Strict** is the cleaned-up standard; **Transitional** keeps
everything old documents need (VML drawings, compatibility settings, the namespaces of ECMA-376).
Office 2010 could read Strict but only write Transitional; Office 2013 and later support Strict,
and still save Transitional by default, for compatibility. So the .pptx files of the world are
Transitional, and that is what xoffy writes.

### The fork

Oracle bought Sun in January 2010 and cut OpenOffice.org's developers. In September 2010 most of
the community left, founded The Document Foundation and forked the code as **LibreOffice**, first
released in January 2011; in June 2011 Oracle gave OpenOffice.org to the Apache Software
Foundation. LibreOffice reads and writes Office Open XML well, which is why this page can show
the slides xoffy writes: it is LibreOffice that draws them. On the other side, Microsoft Office has
read and written ODF since Office 2007 SP2, and ODF 1.4 since Office 2024.
([LibreOffice](https://en.wikipedia.org/wiki/LibreOffice),
[OpenDocument support](https://en.wikipedia.org/wiki/OpenDocument#Application_support))

Two standards, then, both zips of XML, both open in the sense that anyone may read the
specification and implement it. ODF won the standards bodies first; Office Open XML won the
files, because it is what Office saves. Here are the dates in one table.
"""

let years = @["1985", "1987", "1987", "1997", "1999", "2000", "2003", "2005", "2005",
              "2006", "2006", "2007", "2008", "2008", "2010", "2011", "2013"]
let events = @["StarWriter, for a Z80",
               "PowerPoint 1.0, for overheads", "Microsoft buys Forethought",
               "one binary .ppt (Compound File)", "Sun buys StarOffice",
               "OpenOffice.org, open source", "Office 2003 XML formats (one file each)",
               "ODF 1.0, an OASIS standard", "Office Open XML announced at Ecma",
               "ECMA-376", "ISO/IEC 26300 (ODF)", ".pptx is Office's default",
               "ISO ballot passes after Geneva", "ISO/IEC 29500 published",
               "LibreOffice forks", "Apache OpenOffice", "Office supports Strict"]
let sides = @["ODF", "Office", "Office", "Office", "ODF", "ODF", "Office", "ODF", "Office",
              "Office", "ODF", "Office", "Office", "Office", "ODF", "ODF", "Office"]
let history = tableData:
  year: years
  event: events
  side: sides
nbTable tabella(history, groupnameCol = "side"):
  tabHeader "Two formats for one office", "the dates above, by side"
  tabSourceNote md("Sources: the Wikipedia articles linked in the text.")
  optCssTheme()

# ------------------------------------------------------------------------------------- insides

nbText: """
## Inside a .pptx

### A zip

Here is the simplest deck: one slide, one text box.
"""
nbCode:
  var deck = newPresentation()
  deck.add slide(textBox("Hello, Office", box(1.inch, 1.inch, 11.inch, 1.5.inch), Font(size: 54)))
nbSlides deck, "inside-hello", small = true

nbText: """
Rename `hello.pptx` to `hello.zip` and any zip tool opens it. Inside are sixteen files, most of
them for a slide that holds four words. This is all of them, in the order xoffy writes them:
"""
nbPackage deck, "Inside hello.pptx"

nbNote("""
`nbPackage` opens the bytes xoffy wrote with `readZip` and `readPackage`, the same reader the
tests use, and lists every entry. The order is xoffy's: `[Content_Types].xml` first, then the
package's relationships, then each part followed by its own. A zip has no order of its own, but
some tools look for the content types first, so it goes first.
""", nkCode)

nbText: """
The zip is an ordinary one: each file has a small header (its name, size, checksum, how it is
compressed) followed by its bytes, and at the end a *central directory* lists every file and where
its header starts. A reader starts from the end. Office files use two compressions: *stored*
(none) and *deflate*, the one gzip uses. Files above 4 GB need the ZIP64 extension, and a .pptx
is far below it. xoffy writes the zip itself, and takes only deflate and inflate from
[zippy](https://github.com/guzba/zippy).

### Parts, and what they are

Each file in the zip is a **part** of a *package*, as the Open Packaging Conventions (part 2 of the
standard) call it. A part has a name, which is its path, and a **content type**, which says what
it is. They are not in the parts: they are listed in `[Content_Types].xml`, a `Default` for an
extension (every `.rels` is a relationships part, every `.png` an image) and an `Override` for a
single part:
"""
nbXml deck, "[Content_Types].xml", ""

nbText: """
The content type, not the folder, makes `ppt/slides/slide1.xml` a slide. The folders are a
convention: PowerPoint would open a slide called `my/slide.xml` just as well, as long as the
content types and the relationships say what it is.

### Relationships

Parts find each other through **relationships**. Each part that points to others has a
relationships part beside it, in a `_rels` folder, with the same name and `.rels` after it. The
package itself has one too, `_rels/.rels`, and it is where a reader starts: it says which part is
the main one (the *officeDocument*) and where the properties are.
"""
nbXml deck, "_rels/.rels", ""

nbText: """
A relationship has an `Id` (`rId1`, unique in its file), a `Type` (a long URI that says what kind
of link it is) and a `Target`, relative to the folder of the part it belongs to. A slide does not
name its layout or its pictures; it names `rId1`, `rId2`, and its `.rels` says what they are:
"""
nbXml deck, "ppt/slides/_rels/slide1.xml.rels", ""

nbText: """
Follow the relationships from `_rels/.rels` and you get the shape of every presentation:

- the **presentation** (`ppt/presentation.xml`) lists the slides in order, the masters, and the
  size of the slides;
- each **slide** follows a **layout**, which follows a **master**, which takes its colours and
  fonts from a **theme**;
- a slide also points to its pictures, its notes, its charts, and to the URLs of its links
  (an *external* relationship, with `TargetMode="External"`).

### The presentation, and the unit of everything

The presentation is short. Its slide list gives each slide an id and a relationship; the slide
size is in the unit Office measures everything in, the **EMU**, *English Metric Unit*: 914,400
to the inch and 360,000 to the centimetre, so that inches, centimetres and points (12,700 EMU)
are all whole numbers. A 16:9 slide is 12,192,000 × 6,858,000 EMU, 13.33 × 7.5 inches.
"""
nbXml deck, "ppt/presentation.xml", "", open = true

nbText: """
Some numbers you did not want to know, all checked against the schemas of the standard:

- a slide's id is at least 256 and below 2,147,483,648, and a master's or a layout's id is at
  least 2,147,483,648, so the two can never collide;
- a slide is at least one inch and at most 56 inches on each side;
- a font size is in hundredths of a point (`sz="5400"` is 54 pt), from 1 to 4,000 points;
- an angle is in 60,000ths of a degree (`rot="5400000"` is 90°);
- a percentage is in thousandths (`baseline="30000"` raises a superscript by 30%), and an
  opacity in hundred-thousandths (`<a:alpha val="50000"/>` is half transparent).

### Theme, master, layout

A slide inherits almost everything. The **theme** has twelve colours (two darks, two lights, six
accents, two for links), two fonts (one for headings, one for body text), and a *format scheme*
with at least three fills, three lines and three effects: the schema requires them even when no
shape uses them. `scheme(accent1)` in xoffy is a colour of the theme: change
the theme and every shape that uses it changes.

The **master** maps the theme's colours to roles (`tx1` is text, `bg1` the background), holds the
default text styles, and the shapes every slide shows (a logo, a footer). A **layout** is a kind
of slide (Title, Title and Content, Blank...) with **placeholders**: the empty boxes PowerPoint
shows with *Click to add title*. A slide built on a layout fills its placeholders and inherits
their position, size and style.

xoffy 0.1 writes one theme, one master, one **Blank** layout, and places every shape itself. Real
templates, with their layouts and placeholders, are for the next version.

### A slide

At last, the slide. Its shapes are in a *shape tree* (`p:spTree`), drawn in order, the last on
top. The tree starts with a description of itself (it is a group, with no size of its own), the
same in every slide, then the shapes:
"""
nbXml deck, "ppt/slides/slide1.xml", "", open = true

nbText: """
One shape, `p:sp`, in three parts:

1. `p:nvSpPr`, the *non-visual* properties: an id (unique on the slide) and a name, the one
   PowerPoint shows in its selection pane; `txBox="1"` says it is a text box.
2. `p:spPr`, the *shape* properties: where it is (`a:xfrm`, its offset and extent in EMU), its
   outline (`a:prstGeom prst="rect"`, one of the 187 preset shapes), its fill and its line.
3. `p:txBody`, the text: the box's properties (`a:bodyPr`: wrapping, insets, anchor), a list
   style, and the paragraphs (`a:p`), each made of runs (`a:r`) of text (`a:t`) with their
   properties (`a:rPr`: size, bold, colour, font).

The `p:` elements are PresentationML, the slide's own language. Everything with `a:` is
**DrawingML**, shared by the three formats: a shape in a Word document or an Excel sheet has the
same `a:xfrm`, the same `a:prstGeom`, the same paragraphs and runs, in a different frame. That is
why xoffy keeps DrawingML in a module of its own, and why Word and Excel will cost less than
PowerPoint did.

### Shapes, lines, pictures, tables

Each kind of thing on a slide has its own element:

- `p:sp`, a shape: a text box, or one of the 187 presets (ellipses, arrows, stars, callouts,
  flowchart symbols), each drawn from formulas that its adjust values (`a:avLst`) change;
- `p:cxnSp`, a connector, a line from one point to another, with arrows at its ends (a line that
  goes up and left is a box with `flipH` and `flipV`);
- `p:pic`, a picture: its bytes are a part of their own (`ppt/media/image1.png`) and the slide
  points to them with `r:embed`;
- `p:graphicFrame`, a frame for something richer: a table, a chart, a SmartArt diagram. A table is
  DrawingML's `a:tbl`: column widths, then rows of cells, each with its text, its margins, its
  fill and its four borders. A merged cell spans (`gridSpan`, `rowSpan`) and the cells it covers
  stay in the grid, marked `hMerge` or `vMerge`.

Here is a slide with one of each, and its XML:
"""
nbCode:
  var tour = slide(textBox(markdown("One of each: a *shape*, a **connector**, a picture and a table"),
                           box(0.6.inch, 0.4.inch, 12.inch, 0.8.inch), Font(size: 28)))
  tour.add shape(gStar5, box(0.8.inch, 1.8.inch, 2.6.inch, 2.6.inch), rgb"F2B134")
  tour.add connector(3.8.inch, 3.1.inch, 5.2.inch, 3.1.inch, line(rgb"1F1E1D", 2.pt, tail = ahTriangle))
  tour.add picture(solidPng(4, 3, (46, 94, 170)), 5.6.inch, 1.8.inch, w = 3.2.inch)
  var g = newGrid(@[@["a", "b"], @["c", "d"]], colWidth = 1.4.inch)
  g.merge(0, 0, 0, 1)
  g[0, 0].text = frame("a merged cell", align = taCenter)
  g.setBorders(line(rgb"1F1E1D", 1.pt))
  tour.add tableFrame(g, 9.4.inch, 1.8.inch)
  var tourDeck = newPresentation()
  tourDeck.add tour
nbSlides tourDeck, "inside-tour"
nbXml tourDeck, "ppt/slides/slide1.xml", "the slide's XML"

nbText: """
## Things that bite

The schemas say what is valid; PowerPoint is known to be stricter than the schemas, and
LibreOffice is more lenient than both. What we met, or read about, writing xoffy 0.1 (none of it
tried in PowerPoint yet: see the end of the post):

- **Order matters.** The schemas are sequences: `a:rPr` holds its fill, then its fonts, then its
  link, in that order and no other. LibreOffice reads elements in the wrong order; PowerPoint
  says the file needs repair.
- **Some things are required even when empty.** A text body needs at least one paragraph; a
  theme needs three fills, three lines and three effects; a presentation needs a notes size even
  with no notes.
- **Ids.** Shape ids must be unique on their slide, slide ids in their range, relationship ids in
  their file. Two shapes with the same id open in LibreOffice; PowerPoint is reported to repair
  the file.
- **Inherit or nothing.** An attribute left out is inherited: from the layout, the master, the
  theme, or the application's defaults, and applications have different defaults. A table cell
  with no borders gets thin black ones in LibreOffice and none in PowerPoint, so xoffy writes
  "no line" when it means no line.
- **Whitespace is text.** Inside `a:t` every space counts, so xoffy never indents its XML (the
  XML on this page is indented for reading).
- **Fonts are names.** A run says `typeface="Jost"`; if the computer that opens the file has no
  Jost, it picks another font, and the text has another width. Nothing in the file measures text:
  a box does not know how much of it its text fills.
- **Transitional or Strict.** Strict uses other namespaces (`http://purl.oclc.org/ooxml/...`).
  A Transitional reader does not understand a Strict file; write Transitional.

## How xoffy checks what it writes

Three ways, today:

1. **Its tests** read the bytes back (with xoffy's own zip and package reader) and check the
   parts, the relationships, and that every XML part is well formed.
2. **LibreOffice draws every deck** on these pages, at build time: if it could not open one, the
   page would say so.
3. **The schemas of the standard.** While writing 0.1, every deck was checked against the XML
   schemas of ISO/IEC 29500 (Transitional), with a validator that also knows a few rules
   PowerPoint enforces beyond the schemas. All of them pass. The schemas are not in xoffy yet; a
   check that runs in CI is on the [roadmap](../roadmap/).

What is still missing is PowerPoint itself: no file has been opened in it yet. That is the
first thing to do with 0.1.

## Further reading

- The standard: ECMA-376 (free from Ecma International), the same text as ISO/IEC 29500. Part 1
  is the reference of every element, part 2 the packaging, part 3 how the formats grow (markup
  compatibility), part 4 the Transitional features.
- [officeopenxml.com](http://officeopenxml.com/), a readable guide to the elements of the three
  formats, with examples.
- [python-pptx](https://python-pptx.readthedocs.io/)'s documentation, whose *analysis* pages
  explain why each feature works as it does, and its XML.
"""
nbSave
