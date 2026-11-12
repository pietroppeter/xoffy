## DrawingML: colours, lines, text and tables, as every Office format draws them.
##
## PowerPoint, Word and Excel share one drawing language, DrawingML (the `a:` namespace). A slide's
## text box, a shape in a Word document and a chart's title all hold the same `a:p` paragraphs of
## `a:r` runs; a PowerPoint table is an `a:tbl`. This module is that shared language, in Nim
## values and the XML they write. Each format (`xoffy/pptx` today) puts these pieces in its own
## frames.
##
## From the smallest piece up:
##
## - a `Color`: a hex value (`rgb"E16B8C"`), a colour of the theme (`scheme(accent1)`), or none;
## - a `Line`: width, colour, dash, and the arrows at its ends;
## - a `Run`: text with one `Font` (size, bold, italic, colour, typeface, link);
## - a `Paragraph`: runs, aligned, maybe with a bullet;
## - a `TextFrame`: paragraphs in a box, with insets, anchor and wrapping;
## - a `Grid`: column widths, rows, and cells that each hold a TextFrame, a fill and four borders.
##
## ```nim
## import xoffy/[units, drawingml]
## echo run("Hello", Font(bold: true, color: rgb"E16B8C")).runXml
## ```

import std/[strutils, math]
import units, xml

const nsA* = "http://schemas.openxmlformats.org/drawingml/2006/main"

# ---------------------------------------------------------------------------------- colours

type
  SchemeColor* = enum
    ## The colours a theme names; `tx1`/`bg1` are mapped to `dk1`/`lt1` by the master.
    tx1 = "tx1", bg1 = "bg1", tx2 = "tx2", bg2 = "bg2",
    accent1 = "accent1", accent2 = "accent2", accent3 = "accent3",
    accent4 = "accent4", accent5 = "accent5", accent6 = "accent6",
    hlink = "hlink", folHlink = "folHlink"
  ColorKind* = enum
    ckInherit   ## not written: the shape, the cell or the master decides
    ckNone      ## explicitly none: no fill, no line
    ckRgb
    ckScheme
  Color* = object
    kind*: ColorKind
    hex*: string           ## `E16B8C`, for ckRgb
    scheme*: SchemeColor   ## for ckScheme
    alpha*: float          ## opacity, 0..1; 0 means opaque (the default)

const
  inherit* = Color(kind: ckInherit)  ## leave it to the theme
  noColor* = Color(kind: ckNone)     ## no fill, no line

func rgb*(hex: string): Color =
  ## A colour from its hex value: `rgb"E16B8C"`, `rgb"#e16b8c"`, `rgb"#abc"`.
  var h = hex.strip.strip(chars = {'#'}).toUpperAscii
  if h.len == 3: h = h[0] & h[0] & h[1] & h[1] & h[2] & h[2]
  if h.len != 6 or not h.allCharsInSet(HexDigits): raise newException(ValueError, "not a hex colour: " & hex)
  Color(kind: ckRgb, hex: h)

func rgb*(r, g, b: int): Color =
  ## A colour from its red, green and blue, 0..255.
  Color(kind: ckRgb, hex: toHex(clamp(r, 0, 255), 2) & toHex(clamp(g, 0, 255), 2) & toHex(clamp(b, 0, 255), 2))

func scheme*(c: SchemeColor): Color = Color(kind: ckScheme, scheme: c)
  ## A colour of the theme: it changes when the theme does.

func withAlpha*(c: Color, alpha: float): Color =
  ## The same colour, `alpha` opaque (0 transparent, 1 opaque).
  result = c
  result.alpha = clamp(alpha, 0.0, 1.0)
  if result.alpha >= 1: result.alpha = 0

func isSet*(c: Color): bool = c.kind != ckInherit

func colorXml*(c: Color): string =
  ## The colour element alone: `<a:srgbClr val="E16B8C"/>`.
  let inner = if c.alpha > 0: tag("a:alpha", "", {"val": $int(round(c.alpha * 100000))}) else: ""
  case c.kind
  of ckRgb: tag("a:srgbClr", inner, {"val": c.hex})
  of ckScheme: tag("a:schemeClr", inner, {"val": $c.scheme})
  else: ""

func fillXml*(c: Color): string =
  ## A fill: `<a:solidFill>` with the colour, `<a:noFill/>`, or nothing to inherit.
  case c.kind
  of ckInherit: ""
  of ckNone: "<a:noFill/>"
  else: tag("a:solidFill", colorXml(c))

# ------------------------------------------------------------------------------------ lines

type
  Dash* = enum
    dsSolid = "solid", dsDot = "sysDot", dsDash = "dash", dsLongDash = "lgDash",
    dsDashDot = "dashDot", dsRoundDot = "sysDash"
  ArrowHead* = enum
    ahNone = "none", ahTriangle = "triangle", ahStealth = "stealth", ahArrow = "arrow",
    ahOval = "oval", ahDiamond = "diamond"
  Line* = object
    width*: Emu            ## 0: inherit
    color*: Color          ## `noColor`: no line at all
    dash*: Dash
    head*, tail*: ArrowHead  ## the arrows at the start and at the end of a line

const noLine* = Line(color: noColor)

func line*(color: Color, width = 1.pt, dash = dsSolid, head = ahNone, tail = ahNone): Line =
  Line(width: width, color: color, dash: dash, head: head, tail: tail)

func isSet*(l: Line): bool = l.color.kind != ckInherit or int64(l.width) != 0

func lineXml*(l: Line, name = "a:ln"): string =
  ## A line element (`a:ln`, or a cell's `a:lnL` ... `a:lnB`), or nothing to inherit.
  if not l.isSet: return ""
  if l.color.kind == ckNone or (int64(l.width) == 0 and l.color.kind == ckInherit):
    return tag(name, "<a:noFill/>", {"w": "0"})
  var body = fillXml(l.color)
  if l.dash != dsSolid or name != "a:ln": body.add tag("a:prstDash", "", {"val": $l.dash})
  if l.head != ahNone: body.add tag("a:headEnd", "", {"type": $l.head})
  if l.tail != ahNone: body.add tag("a:tailEnd", "", {"type": $l.tail})
  tag(name, body, {"w": (if int64(l.width) > 0: $l.width else: ""), "cmpd": (if name != "a:ln": "sng" else: "")})

# ------------------------------------------------------------------------------------- text

type
  Font* = object
    ## How a run of text looks. Every field left at its default is inherited.
    size*: float           ## in points; 0 inherits
    bold*, italic*, underline*, strike*: bool
    color*: Color
    typeface*: string      ## `"Jost"`; empty inherits the theme's body font
    baseline*: int         ## % raised: 30 for a superscript, -25 for a subscript
    caps*: bool            ## ALL CAPS, as a style (the text keeps its case)
    spacing*: float        ## extra space between letters, in points
  Run* = object
    text*: string
    font*: Font
    link*: string          ## a URL: the run is a hyperlink
  TextAlign* = enum
    taDefault = "", taLeft = "l", taCenter = "ctr", taRight = "r", taJustify = "just"
  BulletKind* = enum bkInherit, bkNone, bkChar, bkNumber
  Bullet* = object
    kind*: BulletKind
    char*: string          ## for bkChar: `"•"`
  Paragraph* = object
    runs*: seq[Run]
    align*: TextAlign
    level*: int            ## the outline level, 0..8
    bullet*: Bullet
    indent*: Emu           ## the left margin of a bulleted paragraph (the bullet hangs in it)
    spaceBefore*, spaceAfter*: float  ## in points
    lineSpacing*: float    ## 1.0 is single; 0 inherits
    endFont*: Font         ## the size of an empty paragraph
  Anchor* = enum anDefault = "", anTop = "t", anMiddle = "ctr", anBottom = "b"
  Autofit* = enum
    afNone     ## the box keeps its size, the text may overflow
    afShrink   ## the text shrinks to fit the box
    afResize   ## the box grows to fit the text
  TextFrame* = object
    paragraphs*: seq[Paragraph]
    insets*: array[4, Emu] ## left, top, right, bottom; `auto` (-1) is Office's default
    anchor*: Anchor
    wrap*: bool            ## wrap lines at the box's width
    autofit*: Autofit
    vertical*: bool        ## text rotated 90°

const auto* = Emu(-1)  ## an inset (or margin) left to Office's default

func run*(text: string, font = Font(), link = ""): Run = Run(text: text, font: font, link: link)

func run*(text: string, size: float, bold = false, italic = false, color = inherit,
          typeface = ""): Run =
  Run(text: text, font: Font(size: size, bold: bold, italic: italic, color: color, typeface: typeface))

func bullet*(c = "•"): Bullet = Bullet(kind: bkChar, char: c)
func numbered*(): Bullet = Bullet(kind: bkNumber)
const noBullet* = Bullet(kind: bkNone)

func para*(runs: varargs[Run]): Paragraph = Paragraph(runs: @runs)
func para*(text: string, font = Font(), align = taDefault): Paragraph =
  Paragraph(runs: @[run(text, font)], align: align, endFont: font)

func frame*(paragraphs: varargs[Paragraph]): TextFrame =
  TextFrame(paragraphs: @paragraphs, insets: [auto, auto, auto, auto], wrap: true)

func frame*(text: string, font = Font(), align = taDefault): TextFrame =
  ## A frame from plain text: one paragraph per line.
  result = frame()
  for line in text.split('\n'): result.paragraphs.add para(line, font, align)

func under*(f, base: Font): Font =
  ## `f`, with what it leaves unset taken from `base`: size, colour, typeface, and bold or italic
  ## when `base` has them.
  result = f
  if result.size == 0: result.size = base.size
  if not result.color.isSet: result.color = base.color
  if result.typeface.len == 0: result.typeface = base.typeface
  result.bold = f.bold or base.bold
  result.italic = f.italic or base.italic
  result.underline = f.underline or base.underline
  result.caps = f.caps or base.caps

func withFont*(t: TextFrame, font: Font): TextFrame =
  ## The frame, every run (and every empty paragraph) in `font` where it says nothing of its own.
  result = t
  for p in result.paragraphs.mitems:
    for r in p.runs.mitems: r.font = r.font.under(font)
    p.endFont = p.endFont.under(font)

# ----------------------------------------------------------- a little Markdown, as runs

func inline*(md: string, font = Font()): seq[Run] =
  ## Runs from one line of inline Markdown: `**bold**`, `*italic*` or `_italic_`, `` `code` ``
  ## (in Menlo), `~~strike~~`, `^super^`, `~sub~` and `[a link](https://...)`. Everything else
  ## is text.
  var f = font
  var cur = ""
  proc flush(result: var seq[Run], cur: var string, f: Font) =
    if cur.len > 0: result.add Run(text: cur, font: f)
    cur = ""
  var i = 0
  while i < md.len:
    let c = md[i]
    if c == '\\' and i + 1 < md.len:
      cur.add md[i + 1]; i += 2; continue
    if md.continuesWith("**", i):
      flush(result, cur, f); f.bold = not f.bold; i += 2; continue
    if md.continuesWith("~~", i):
      flush(result, cur, f); f.strike = not f.strike; i += 2; continue
    if c in {'*', '_'} and (c == '*' or i == 0 or md[i - 1] in Whitespace + {'(', '*'} or f.italic):
      flush(result, cur, f); f.italic = not f.italic; inc i; continue
    if c == '^':
      flush(result, cur, f); f.baseline = (if f.baseline == 30: 0 else: 30); inc i; continue
    if c == '~':
      flush(result, cur, f); f.baseline = (if f.baseline == -25: 0 else: -25); inc i; continue
    if c == '`':
      let close = md.find('`', i + 1)
      if close > i:
        flush(result, cur, f)
        var code = f
        code.typeface = "Menlo"
        result.add Run(text: md[i + 1 ..< close], font: code)
        i = close + 1; continue
    if c == '[':
      let mid = md.find("](", i)
      let close = if mid > 0: md.find(')', mid) else: -1
      if mid > i and close > mid:
        flush(result, cur, f)
        for r in inline(md[i + 1 ..< mid], f):
          var r = r
          r.link = md[mid + 2 ..< close]
          result.add r
        i = close + 1; continue
    cur.add c
    inc i
  flush(result, cur, f)

func markdown*(text: string, font = Font(), align = taDefault): TextFrame =
  ## A frame from a little Markdown: one paragraph per line, `- ` starts a bulleted one,
  ## `1. ` a numbered one, and each line's inline Markdown becomes runs (see `inline`).
  result = frame()
  for line in text.split('\n'):
    var p = Paragraph(align: align, endFont: font)
    var l = line
    let lead = l.len - l.strip(trailing = false).len
    l = l.strip(trailing = false)
    if l.startsWith("- ") or l.startsWith("* "):
      p.bullet = bullet()
      p.level = lead div 2
      l = l[2 .. ^1]
    elif l.len > 2 and l[0].isDigit and l.find(". ") in 1..3 and l[0 ..< l.find(". ")].allCharsInSet(Digits):
      p.bullet = numbered()
      p.level = lead div 2
      l = l[l.find(". ") + 2 .. ^1]
    p.runs = inline(l, font)
    result.paragraphs.add p

# ----------------------------------------------------------------------- text, as XML

type LinkSink* = proc (url: string): string
  ## Gives the relationship id (`rId3`) of a hyperlink: each format keeps its own relationships.

func hundredths(pt: float): string = $int(round(pt * 100))

proc fontXml*(f: Font, name = "a:rPr", link = "", links: LinkSink = nil): string =
  ## The run properties: `<a:rPr sz="1800" b="1">...</a:rPr>`, or `name` (`a:defRPr`,
  ## `a:endParaRPr`) for the same properties elsewhere.
  var body = fillXml(f.color)
  if f.typeface.len > 0:
    body.add tag("a:latin", "", {"typeface": f.typeface}) & tag("a:cs", "", {"typeface": f.typeface})
  if link.len > 0 and links != nil:
    body.add "<a:hlinkClick r:id=\"" & links(link) & "\"/>"
  tag(name, body, {"lang": (if name == "a:defRPr": "" else: "en-US"),
                   "sz": (if f.size > 0: hundredths(f.size) else: ""),
                   "b": (if f.bold: "1" else: ""), "i": (if f.italic: "1" else: ""),
                   "u": (if f.underline: "sng" else: ""), "strike": (if f.strike: "sngStrike" else: ""),
                   "cap": (if f.caps: "all" else: ""),
                   "spc": (if f.spacing != 0: hundredths(f.spacing) else: ""),
                   "baseline": (if f.baseline != 0: $(f.baseline * 1000) else: "")})

proc runXml*(r: Run, links: LinkSink = nil): string =
  ## `<a:r>` with its properties and text; a newline in the text is a line break (`<a:br/>`).
  let pieces = r.text.split('\n')
  for k, piece in pieces:
    if k > 0: result.add tag("a:br", fontXml(r.font, links = nil))
    result.add "<a:r>" & fontXml(r.font, link = r.link, links = links) & "<a:t>" & esc(piece) & "</a:t></a:r>"

proc paragraphXml*(p: Paragraph, links: LinkSink = nil): string =
  var props = ""
  if p.lineSpacing > 0: props.add tag("a:lnSpc", tag("a:spcPct", "", {"val": $int(round(p.lineSpacing * 100000))}))
  if p.spaceBefore > 0: props.add tag("a:spcBef", tag("a:spcPts", "", {"val": hundredths(p.spaceBefore)}))
  if p.spaceAfter > 0: props.add tag("a:spcAft", tag("a:spcPts", "", {"val": hundredths(p.spaceAfter)}))
  var marL, indent = ""
  case p.bullet.kind
  of bkInherit: discard
  of bkNone: props.add "<a:buNone/>"
  of bkChar:
    props.add tag("a:buFont", "", {"typeface": "Arial"}) & tag("a:buChar", "", {"char": p.bullet.char})
  of bkNumber:
    props.add tag("a:buFont", "", {"typeface": "+mj-lt"}) & tag("a:buAutoNum", "", {"type": "arabicPeriod"})
  if p.bullet.kind in {bkChar, bkNumber}:
    # the hanging indent the bullet sits in: given, or about one em of the paragraph's text
    var size = p.endFont.size
    for r in p.runs:
      if r.font.size > 0: (size = r.font.size; break)
    let step = if int64(p.indent) > 0: p.indent else: max(18.pt, (1.1 * (if size > 0: size else: 18.0)).pt)
    marL = $(step * (p.level + 1))
    indent = $(-step)
  let pPr = tag("a:pPr", props, {"marL": marL, "lvl": (if p.level > 0: $p.level else: ""),
                                 "indent": indent, "algn": $p.align})
  result = "<a:p>" & (if pPr == "<a:pPr/>": "" else: pPr)
  for r in p.runs: result.add runXml(r, links)
  result.add fontXml(p.endFont, "a:endParaRPr")
  result.add "</a:p>"

proc bodyPrXml*(t: TextFrame, wrapDefault = true): string =
  let fit = case t.autofit
    of afNone: ""
    of afShrink: "<a:normAutofit/>"
    of afResize: "<a:spAutoFit/>"
  func ins(e: Emu): string = (if int64(e) >= 0: $e else: "")
  tag("a:bodyPr", fit, {"vert": (if t.vertical: "vert" else: ""),
                        "wrap": (if t.wrap: "square" else: "none"),
                        "lIns": ins(t.insets[0]), "tIns": ins(t.insets[1]),
                        "rIns": ins(t.insets[2]), "bIns": ins(t.insets[3]),
                        "rtlCol": "0", "anchor": $t.anchor})

proc paragraphsXml*(t: TextFrame, links: LinkSink = nil): string =
  if t.paragraphs.len == 0: return "<a:p><a:endParaRPr lang=\"en-US\"/></a:p>"
  for p in t.paragraphs: result.add paragraphXml(p, links)

proc textBodyXml*(t: TextFrame, name: string, links: LinkSink = nil): string =
  ## The text in a box: `<p:txBody>` in a slide, `<a:txBody>` in a table cell.
  tag(name, bodyPrXml(t) & "<a:lstStyle/>" & paragraphsXml(t, links))

func plainText*(t: TextFrame): string =
  ## The text alone, one line per paragraph.
  var lines: seq[string]
  for p in t.paragraphs:
    var s = ""
    for r in p.runs: s.add r.text
    lines.add s
  lines.join("\n")

# ------------------------------------------------------------------------------- geometry

type Geometry* = enum
  ## The preset shapes Office draws (a few of its 187), by their DrawingML names.
  gRect = "rect", gRoundRect = "roundRect", gEllipse = "ellipse", gTriangle = "triangle",
  gRightTriangle = "rtTriangle", gDiamond = "diamond", gPentagon = "pentagon",
  gHexagon = "hexagon", gOctagon = "octagon", gParallelogram = "parallelogram",
  gTrapezoid = "trapezoid", gStar5 = "star5", gStar8 = "star8", gPlus = "plus",
  gHeart = "heart", gCloud = "cloud", gDonut = "donut", gArc = "arc", gChord = "chord",
  gPie = "pie", gBlockArc = "blockArc", gCan = "can", gCube = "cube",
  gRightArrow = "rightArrow", gLeftArrow = "leftArrow", gUpArrow = "upArrow",
  gDownArrow = "downArrow", gChevron = "chevron", gHomePlate = "homePlate",
  gCallout = "wedgeRectCallout", gRoundCallout = "wedgeEllipseCallout",
  gLine = "line", gSnipRect = "snip1Rect", gFoldedCorner = "foldedCorner",
  gHalfFrame = "halfFrame", gFrame = "frame", gLightning = "lightningBolt", gMoon = "moon",
  gSun = "sun", gSmiley = "smileyFace", gNoSmoking = "noSmoking", gTeardrop = "teardrop",
  gWave = "wave", gFlowProcess = "flowChartProcess", gFlowDecision = "flowChartDecision",
  gFlowTerminator = "flowChartTerminator", gFlowDocument = "flowChartDocument",
  gFlowData = "flowChartInputOutput"

type Box* = object
  ## Where a shape is on the page: its top left corner and its size.
  x*, y*, w*, h*: Emu
  rotation*: float       ## clockwise, in degrees
  flipH*, flipV*: bool

func box*(x, y, w, h: Emu, rotation = 0.0): Box = Box(x: x, y: y, w: w, h: h, rotation: rotation)

func xfrmXml*(b: Box, name = "a:xfrm"): string =
  tag(name, tag("a:off", "", {"x": $b.x, "y": $b.y}) & tag("a:ext", "", {"cx": $b.w, "cy": $b.h}),
      {"rot": (if b.rotation != 0: $int(round(b.rotation * 60000)) else: ""),
       "flipH": (if b.flipH: "1" else: ""), "flipV": (if b.flipV: "1" else: "")})

func geometryXml*(g: Geometry, adjust: openArray[(string, int)] = []): string =
  ## `<a:prstGeom prst="ellipse">`, with the shape's adjust values (`adj`, in 1/100000).
  var av = ""
  for (name, v) in adjust: av.add tag("a:gd", "", {"name": name, "fmla": "val " & $v})
  tag("a:prstGeom", tag("a:avLst", av), {"prst": $g})

# ---------------------------------------------------------------------------------- tables

type
  Edge* = enum edLeft, edRight, edTop, edBottom
  GridCell* = object
    text*: TextFrame
    fill*: Color
    borders*: array[Edge, Line]
    margins*: array[Edge, Emu]   ## `auto` (-1) is Office's default (0.1 inch left and right, 0.05 inch top and bottom)
    anchor*: Anchor
    span*, rowSpan*: int         ## how many columns and rows the cell covers (1 or 0: one)
    hMerge*, vMerge*: bool       ## covered by the cell to the left / above
  GridRow* = object
    height*: Emu
    cells*: seq[GridCell]
  Grid* = object
    ## A DrawingML table: the same in a slide (`a:tbl` in a graphic frame) and, later, in a chart.
    cols*: seq[Emu]              ## the column widths
    rows*: seq[GridRow]
    styleId*: string             ## a table style's GUID; empty: no style, only what the cells say
    firstRow*, bandRow*: bool    ## the style's options

func cell*(text: TextFrame, fill = inherit): GridCell =
  GridCell(text: text, fill: fill, margins: [auto, auto, auto, auto])

func cell*(text: string, font = Font(), align = taDefault, fill = inherit): GridCell =
  cell(frame(text, font, align), fill)

func newGrid*(rows, cols: int, colWidth = 1.inch, rowHeight = 0.4.inch): Grid =
  ## A table of empty cells, every column `colWidth` wide.
  for c in 0 ..< cols: result.cols.add colWidth
  for r in 0 ..< rows:
    var row = GridRow(height: rowHeight)
    for c in 0 ..< cols: row.cells.add cell("")
    result.rows.add row

func newGrid*(data: openArray[seq[string]], colWidth = 1.inch, rowHeight = 0.4.inch, font = Font()): Grid =
  ## A table of the given rows of text.
  var cols = 0
  for r in data: cols = max(cols, r.len)
  result = newGrid(data.len, cols, colWidth, rowHeight)
  for i, r in data:
    for j, s in r: result.rows[i].cells[j].text = frame(s, font)

func width*(t: Grid): Emu = sum(t.cols)
func height*(t: Grid): Emu =
  for r in t.rows: result += r.height

proc `[]`*(t: var Grid, r, c: int): var GridCell = t.rows[r].cells[c]
func `[]`*(t: Grid, r, c: int): GridCell = t.rows[r].cells[c]

proc merge*(t: var Grid, r1, c1, r2, c2: int) =
  ## Merges the cells from row `r1`, column `c1` to row `r2`, column `c2` (both included) into the
  ## first: it spans them, and the others are marked as covered.
  for r in r1 .. r2:
    for c in c1 .. c2:
      t.rows[r].cells[c].hMerge = c > c1
      t.rows[r].cells[c].vMerge = r > r1
  t.rows[r1].cells[c1].span = c2 - c1 + 1
  t.rows[r1].cells[c1].rowSpan = r2 - r1 + 1

proc setBorders*(t: var Grid, l: Line, sides = {edLeft, edRight, edTop, edBottom}) =
  ## The same line on the given sides of every cell.
  for row in t.rows.mitems:
    for c in row.cells.mitems:
      for s in sides: c.borders[s] = l

func stronger(a, b: Line): Line =
  ## Of two lines for the same edge: one that is set over one that inherits, a line over no line,
  ## then the wider (on a tie, `a`). CSS's border-collapse, roughly.
  func rank(l: Line): int =
    if not l.isSet: 0 elif l.color.kind == ckNone: 1 else: 2
  if rank(b) > rank(a) or (rank(b) == 2 and rank(a) == 2 and int64(b.width) > int64(a.width)): b
  else: a

proc collapseBorders*(t: var Grid) =
  ## Two cells side by side share one edge, and PowerPoint keeps a single line for it, the top
  ## or left cell's: a line set only on the other side is lost. This gives both sides the stronger
  ## line. `tableXml` does it on its own copy of the grid.
  for i in 0 ..< t.rows.len:
    for k in 0 ..< t.rows[i].cells.len:
      if k + 1 < t.rows[i].cells.len:
        let l = stronger(t.rows[i].cells[k].borders[edRight], t.rows[i].cells[k+1].borders[edLeft])
        t.rows[i].cells[k].borders[edRight] = l
        t.rows[i].cells[k+1].borders[edLeft] = l
      if i + 1 < t.rows.len and k < t.rows[i+1].cells.len:
        let l = stronger(t.rows[i].cells[k].borders[edBottom], t.rows[i+1].cells[k].borders[edTop])
        t.rows[i].cells[k].borders[edBottom] = l
        t.rows[i+1].cells[k].borders[edTop] = l

proc cellXml*(c: GridCell, links: LinkSink = nil, plain = false): string =
  ## A cell. With `plain` (a grid with no style), a side with no line says so, because
  ## applications disagree on what a cell with nothing to say draws.
  let attrs = {"gridSpan": (if c.span > 1: $c.span else: ""), "rowSpan": (if c.rowSpan > 1: $c.rowSpan else: ""),
               "hMerge": (if c.hMerge: "1" else: ""), "vMerge": (if c.vMerge: "1" else: "")}
  let text = if c.hMerge or c.vMerge: frame() else: c.text
  var pr = ""
  for s, name in [edLeft: "a:lnL", edRight: "a:lnR", edTop: "a:lnT", edBottom: "a:lnB"]:
    pr.add lineXml((if plain and not c.borders[s].isSet: noLine else: c.borders[s]), name)
  pr.add fillXml(c.fill)
  func m(e: Emu): string = (if int64(e) >= 0: $e else: "")
  tag("a:tc", textBodyXml(text, "a:txBody", links) &
      tag("a:tcPr", pr, {"marL": m(c.margins[edLeft]), "marR": m(c.margins[edRight]),
                         "marT": m(c.margins[edTop]), "marB": m(c.margins[edBottom]),
                         "anchor": $c.anchor}), attrs)

proc tableXml*(t: Grid, links: LinkSink = nil): string =
  ## `<a:tbl>`: its properties, the grid of column widths, and the rows.
  var t = t
  t.collapseBorders
  var props = ""
  if t.styleId.len > 0: props = tag("a:tableStyleId", t.styleId)
  result = "<a:tbl>" & tag("a:tblPr", props, {"firstRow": (if t.firstRow: "1" else: ""),
                                               "bandRow": (if t.bandRow: "1" else: "")}) & "<a:tblGrid>"
  for w in t.cols: result.add tag("a:gridCol", "", {"w": $w})
  result.add "</a:tblGrid>"
  for r in t.rows:
    result.add "<a:tr h=\"" & $r.height & "\">"
    for c in r.cells: result.add cellXml(c, links, plain = t.styleId.len == 0)
    result.add "</a:tr>"
  result.add "</a:tbl>"
