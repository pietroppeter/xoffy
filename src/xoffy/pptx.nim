## PowerPoint: a presentation of slides, each with its shapes.
##
## A .pptx is a package (`xoffy/opc`) whose main part, `ppt/presentation.xml`, lists the slides
## and their size. Every slide (`ppt/slides/slide1.xml`) is a tree of shapes drawn with DrawingML
## (`xoffy/drawingml`), and follows a layout, which follows a master, which takes its colours and
## fonts from a theme. xoffy writes one master with one blank layout, and a theme made from a
## `Theme` value: everything on a slide is a shape you place.
##
## The shapes, from the simplest:
##
## - `textBox`: text in a box;
## - `shape`: one of Office's preset shapes (`gEllipse`, `gRightArrow`, ...), filled, outlined,
##   maybe with text;
## - `connector`: a line from one point to another, maybe with arrows;
## - `picture`: a PNG, JPEG or GIF;
## - `tableFrame`: a native table (`Grid`), that PowerPoint lets you edit.
##
## ```nim
## import xoffy
## var deck = newPresentation()
## deck.add slide(textBox("Hello, Office", box(1.inch, 1.inch, 8.inch, 1.inch), Font(size: 40)))
## deck.save "hello.pptx"
## ```

import std/[strutils, tables, os]

import units, xml, opc, drawingml, images

const
  nsP* = "http://schemas.openxmlformats.org/presentationml/2006/main"
  nsR* = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  nsAll = " xmlns:a=\"" & nsA & "\" xmlns:r=\"" & nsR & "\" xmlns:p=\"" & nsP & "\""
  ctPresentation* = "application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"
  ctSlide* = "application/vnd.openxmlformats-officedocument.presentationml.slide+xml"
  ctSlideLayout* = "application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"
  ctSlideMaster* = "application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"
  ctPresProps* = "application/vnd.openxmlformats-officedocument.presentationml.presProps+xml"
  ctViewProps* = "application/vnd.openxmlformats-officedocument.presentationml.viewProps+xml"
  ctTableStyles* = "application/vnd.openxmlformats-officedocument.presentationml.tableStyles+xml"
  relSlide* = relBase & "slide"
  relSlideLayout* = relBase & "slideLayout"
  relSlideMaster* = relBase & "slideMaster"
  tableUri = "http://schemas.openxmlformats.org/drawingml/2006/table"

# ------------------------------------------------------------------------------------ shapes

type
  ShapeKind* = enum skShape, skConnector, skPicture, skTable
  Picture* = object
    data*: string          ## the bytes of the file
    info*: ImageInfo
    description*: string   ## the alternative text
  Shape* = object
    ## Anything on a slide. Which fields count depends on `kind`.
    kind*: ShapeKind
    name*: string          ## shown in PowerPoint's selection pane
    box*: Box
    geometry*: Geometry    ## skShape: its outline (`gRect` for a text box)
    adjust*: seq[(string, int)]  ## skShape: the preset's adjust values (`("adj", 25000)`)
    fill*: Color
    line*: Line
    text*: TextFrame
    isTextBox*: bool       ## a text box: PowerPoint treats it as text first
    picture*: Picture      ## skPicture
    table*: Grid          ## skTable
    link*: string          ## a URL to open when the shape is clicked

func textBox*(text: TextFrame, b: Box): Shape =
  ## A text box: text in a rectangle with no fill and no line.
  Shape(kind: skShape, box: b, geometry: gRect, text: text, isTextBox: true, name: "Text")

func textBox*(text: TextFrame, b: Box, font: Font): Shape =
  ## A text box, its text in `font` wherever it says nothing of its own.
  textBox(text.withFont(font), b)

func textBox*(text: string, b: Box, font = Font(), align = taDefault): Shape =
  ## A text box of plain text, one paragraph per line.
  textBox(frame(text, font, align), b)

func shape*(geometry: Geometry, b: Box, fill = inherit, line = Line(), text = frame()): Shape =
  ## A preset shape. With no fill or line given, it is drawn in the theme's first accent colour.
  Shape(kind: skShape, box: b, geometry: geometry,
        fill: (if fill.isSet: fill else: scheme(accent1)),
        line: (if line.isSet: line else: noLine), text: text, name: ($geometry).capitalizeAscii)

func shape*(geometry: Geometry, b: Box, fill: Color, text: string, font = Font(), align = taCenter): Shape =
  var t = frame(text, font, align)
  t.anchor = anMiddle
  shape(geometry, b, fill, noLine, t)

func connector*(x1, y1, x2, y2: Emu, line = line(scheme(tx1))): Shape =
  ## A straight line from (x1, y1) to (x2, y2); give `line.tail = ahTriangle` for an arrow.
  var b = Box(x: min(x1, x2), y: min(y1, y2), w: max(x1, x2) - min(x1, x2), h: max(y1, y2) - min(y1, y2))
  b.flipH = x2 < x1
  b.flipV = y2 < y1
  Shape(kind: skConnector, box: b, geometry: gLine, line: line, name: "Line")

func picture*(data: string, x, y: Emu, w = Emu(0), h = Emu(0), description = ""): Shape =
  ## A picture from the bytes of a PNG, JPEG or GIF. Give its width or its height and the other
  ## keeps the picture's proportions; give neither and it is shown at 96 pixels to the inch.
  let info = imageInfo(data)
  var (w, h) = (w, h)
  if int64(w) == 0 and int64(h) == 0: (w, h) = (info.width.px, info.height.px)
  elif int64(h) == 0: h = w * (info.height / info.width)
  elif int64(w) == 0: w = h * (info.width / info.height)
  Shape(kind: skPicture, box: box(x, y, w, h), name: "Picture",
        picture: Picture(data: data, info: info, description: description))

proc pictureFile*(path: string, x, y: Emu, w = Emu(0), h = Emu(0), description = ""): Shape =
  ## A picture from a file.
  result = picture(readFile(path), x, y, w, h, description)
  result.name = path.extractFilename

func tableFrame*(t: Grid, x, y: Emu): Shape =
  ## A native table, with its top left corner at (x, y); its size is its columns' and rows'.
  Shape(kind: skTable, box: box(x, y, t.width, t.height), table: t, name: "Table")

# ------------------------------------------------------------------------------------ slides

type
  Slide* = object
    shapes*: seq[Shape]
    background*: Color     ## inherit: the theme's background (`bg1`)
    name*: string
  Theme* = object
    ## The colours and fonts every slide can refer to (`scheme(accent1)`, the body font).
    name*: string
    dark1*, light1*, dark2*, light2*: string     ## text and background colours, as hex
    accents*: array[6, string]                   ## `accent1` .. `accent6`
    link*, followedLink*: string
    headingFont*, bodyFont*: string
  Presentation* = object
    width*, height*: Emu   ## the slide size
    slides*: seq[Slide]
    theme*: Theme
    title*, author*: string

const
  officeTheme* = Theme(name: "xoffy", dark1: "000000", light1: "FFFFFF", dark2: "44546A", light2: "E7E6E6",
                       accents: ["4472C4", "ED7D31", "A5A5A5", "FFC000", "5B9BD5", "70AD47"],
                       link: "0563C1", followedLink: "954F72", headingFont: "Calibri Light", bodyFont: "Calibri")
    ## the colours and fonts of Office's own default theme
  widescreen* = (Emu(12_192_000), 7.5.inch)  ## 16:9 (13.333 × 7.5 inches), PowerPoint's default
  standard* = (10.inch, 7.5.inch)        ## 4:3

func newPresentation*(size = widescreen, theme = officeTheme, title = "", author = ""): Presentation =
  Presentation(width: size[0], height: size[1], theme: theme, title: title, author: author)

func slide*(shapes: varargs[Shape]): Slide = Slide(shapes: @shapes)
  ## A slide with these shapes, drawn in this order (the last on top).

func slide*(background: Color, shapes: varargs[Shape]): Slide = Slide(shapes: @shapes, background: background)
  ## A slide with its own background.

proc add*(s: var Slide, sh: Shape) = s.shapes.add sh
proc add*(p: var Presentation, s: Slide) = p.slides.add s

# --------------------------------------------------------------------------------- the XML

const emptyTree = "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" &
  "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/>" &
  "<a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>"

proc shapeXml*(s: Shape, id: int, links: LinkSink = nil, media: proc (p: Picture): string = nil): string =
  ## One shape of a slide's tree. `links` gives the relationship id of a URL, `media` that of
  ## a picture (the presentation's writer keeps both).
  let name = if s.name.len > 0: s.name & " " & $id else: "Shape " & $id
  let click = if s.link.len > 0 and links != nil: "<a:hlinkClick r:id=\"" & links(s.link) & "\"/>" else: ""
  let nv = "<p:cNvPr id=\"" & $id & "\" name=\"" & esc(name) & "\"" &
           (if s.kind == skPicture and s.picture.description.len > 0: " descr=\"" & esc(s.picture.description) & "\"" else: "") &
           (if click.len > 0: ">" & click & "</p:cNvPr>" else: "/>")
  case s.kind
  of skShape:
    "<p:sp><p:nvSpPr>" & nv & (if s.isTextBox: "<p:cNvSpPr txBox=\"1\"/>" else: "<p:cNvSpPr/>") &
      "<p:nvPr/></p:nvSpPr><p:spPr>" & xfrmXml(s.box) & geometryXml(s.geometry, s.adjust) &
      (if s.isTextBox and not s.fill.isSet: "<a:noFill/>" else: fillXml(s.fill)) &
      lineXml(s.line) & "</p:spPr>" & textBodyXml(s.text, "p:txBody", links) & "</p:sp>"
  of skConnector:
    "<p:cxnSp><p:nvCxnSpPr>" & nv & "<p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr><p:spPr>" &
      xfrmXml(s.box) & geometryXml(gLine) & lineXml(s.line) & "</p:spPr></p:cxnSp>"
  of skPicture:
    let rid = if media != nil: media(s.picture) else: ""
    "<p:pic><p:nvPicPr>" & nv & "<p:cNvPicPr><a:picLocks noChangeAspect=\"1\"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>" &
      "<p:blipFill><a:blip r:embed=\"" & rid & "\"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>" &
      "<p:spPr>" & xfrmXml(s.box) & geometryXml(gRect) & lineXml(s.line) & "</p:spPr></p:pic>"
  of skTable:
    "<p:graphicFrame><p:nvGraphicFramePr>" & nv &
      "<p:cNvGraphicFramePr><a:graphicFrameLocks noGrp=\"1\"/></p:cNvGraphicFramePr><p:nvPr/></p:nvGraphicFramePr>" &
      xfrmXml(s.box, "p:xfrm") & "<a:graphic><a:graphicData uri=\"" & tableUri & "\">" &
      tableXml(s.table, links) & "</a:graphicData></a:graphic></p:graphicFrame>"

proc slideXml*(s: Slide, links: LinkSink = nil, media: proc (p: Picture): string = nil): string =
  ## A slide part: its background, then its shapes, numbered from 2 (1 is the tree itself).
  var tree = emptyTree
  for k, sh in s.shapes: tree.add shapeXml(sh, k + 2, links, media)
  let bg = if s.background.isSet: "<p:bg><p:bgPr>" & fillXml(s.background) & "<a:effectLst/></p:bgPr></p:bg>" else: ""
  doc("<p:sld" & nsAll & "><p:cSld" & attrs({"name": s.name}) & ">" & bg & "<p:spTree>" & tree &
      "</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>")

func themeXml*(t: Theme): string =
  ## The theme part: twelve colours, two fonts, and the plain fill, line and effect styles that
  ## PowerPoint requires (three of each).
  func c(name, hex: string): string = tag("a:" & name, tag("a:srgbClr", "", {"val": hex}))
  var colors = c("dk1", t.dark1) & c("lt1", t.light1) & c("dk2", t.dark2) & c("lt2", t.light2)
  for k, a in t.accents: colors.add c("accent" & $(k + 1), a)
  colors.add c("hlink", t.link) & c("folHlink", t.followedLink)
  func font(kind, face: string): string =
    tag("a:" & kind, tag("a:latin", "", {"typeface": face}) & "<a:ea typeface=\"\"/><a:cs typeface=\"\"/>")
  let ph = "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>"
  doc tag("a:theme", "<a:themeElements>" & tag("a:clrScheme", colors, {"name": t.name}) &
    tag("a:fontScheme", font("majorFont", t.headingFont) & font("minorFont", t.bodyFont), {"name": t.name}) &
    tag("a:fmtScheme", "<a:fillStyleLst>" & ph & ph & ph & "</a:fillStyleLst><a:lnStyleLst>" &
      "<a:ln w=\"6350\">" & ph & "</a:ln><a:ln w=\"12700\">" & ph & "</a:ln><a:ln w=\"19050\">" & ph & "</a:ln>" &
      "</a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/>" &
      "</a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst>" &
      ph & ph & ph & "</a:bgFillStyleLst>", {"name": t.name}) &
    "</a:themeElements><a:objectDefaults/><a:extraClrSchemeLst/>", {"xmlns:a": nsA, "name": t.name})

const textStyle = "<a:lvl1pPr marL=\"0\" algn=\"l\"><a:defRPr sz=\"1800\"><a:solidFill><a:schemeClr val=\"tx1\"/>" &
  "</a:solidFill><a:latin typeface=\"+mn-lt\"/><a:ea typeface=\"+mn-ea\"/><a:cs typeface=\"+mn-cs\"/></a:defRPr></a:lvl1pPr>"
  ## text that says nothing about itself: 18 pt, the body font, the text colour

func masterXml(): string =
  doc("<p:sldMaster" & nsAll & "><p:cSld><p:bg><p:bgRef idx=\"1001\"><a:schemeClr val=\"bg1\"/></p:bgRef></p:bg>" &
    "<p:spTree>" & emptyTree & "</p:spTree></p:cSld>" &
    "<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\" accent1=\"accent1\" accent2=\"accent2\" " &
    "accent3=\"accent3\" accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\" hlink=\"hlink\" folHlink=\"folHlink\"/>" &
    "<p:sldLayoutIdLst><p:sldLayoutId id=\"2147483649\" r:id=\"rId1\"/></p:sldLayoutIdLst>" &
    "<p:txStyles><p:titleStyle>" & textStyle & "</p:titleStyle><p:bodyStyle>" & textStyle &
    "</p:bodyStyle><p:otherStyle>" & textStyle & "</p:otherStyle></p:txStyles></p:sldMaster>")

func layoutXml(): string =
  doc("<p:sldLayout" & nsAll & " type=\"blank\" preserve=\"1\"><p:cSld name=\"Blank\"><p:spTree>" & emptyTree &
    "</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>")

proc toPackage*(p: Presentation): Package =
  ## The presentation as a package: its parts and their relationships.
  result = Package()
  result.add "ppt/presentation.xml", ctPresentation, ""   # written last, once the slides have ids
  discard result.relate("", "ppt/presentation.xml", relOfficeDocument)
  discard result.relate("", "docProps/core.xml", relCoreProperties)
  discard result.relate("", "docProps/app.xml", relExtendedProperties)
  result.add "docProps/core.xml", ctCoreProperties, doc(
    "<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" " &
    "xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:dcterms=\"http://purl.org/dc/terms/\" " &
    "xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">" &
    (if p.title.len > 0: tag("dc:title", esc(p.title)) else: "") &
    (if p.author.len > 0: tag("dc:creator", esc(p.author)) else: "") & "</cp:coreProperties>")
  result.add "docProps/app.xml", ctExtendedProperties, doc(
    "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\">" &
    "<Application>xoffy</Application><Slides>" & $p.slides.len & "</Slides></Properties>")
  const pres = "ppt/presentation.xml"
  const master = "ppt/slideMasters/slideMaster1.xml"
  const layout = "ppt/slideLayouts/slideLayout1.xml"
  const theme = "ppt/theme/theme1.xml"
  let masterId = result.relate(pres, master, relSlideMaster)
  result.add master, ctSlideMaster, masterXml()
  discard result.relate(master, layout, relSlideLayout)
  discard result.relate(master, theme, relTheme)
  result.add layout, ctSlideLayout, layoutXml()
  discard result.relate(layout, master, relSlideMaster)
  result.add theme, ctTheme, themeXml(p.theme)
  discard result.relate(pres, theme, relTheme)
  var media = initTable[string, string]()   # the bytes of a picture, to its part: each picture once
  var slideIds = ""
  for k, s in p.slides:
    let name = "ppt/slides/slide" & $(k + 1) & ".xml"
    let rid = result.relate(pres, name, relSlide)
    slideIds.add "<p:sldId id=\"" & $(256 + k) & "\" r:id=\"" & rid & "\"/>"
    discard result.relate(name, layout, relSlideLayout)
    var pkg = addr result
    let links: LinkSink = proc (url: string): string = pkg[].relate(name, url, relHyperlink, external = true)
    let pics = proc (pic: Picture): string =
      if not media.hasKey(pic.data):
        let part = "ppt/media/image" & $(media.len + 1) & "." & pic.info.ext
        media[pic.data] = part
        pkg[].add part, pic.info.contentType, pic.data
      pkg[].relate(name, media[pic.data], relImage)
    result.add name, ctSlide, slideXml(s, links, pics)
  for (name, ct, body) in [("ppt/presProps.xml", ctPresProps, "<p:presentationPr" & nsAll & "/>"),
                           ("ppt/viewProps.xml", ctViewProps, "<p:viewPr" & nsAll & ">" &
                             "<p:gridSpacing cx=\"76200\" cy=\"76200\"/></p:viewPr>"),
                           ("ppt/tableStyles.xml", ctTableStyles, "<a:tblStyleLst xmlns:a=\"" & nsA &
                             "\" def=\"{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}\"/>")]:
    result.add name, ct, doc(body)
  discard result.relate(pres, "ppt/presProps.xml", relBase & "presProps")
  discard result.relate(pres, "ppt/viewProps.xml", relBase & "viewProps")
  discard result.relate(pres, "ppt/tableStyles.xml", relBase & "tableStyles")
  result.add pres, ctPresentation, doc("<p:presentation" & nsAll & " saveSubsetFonts=\"1\">" &
    "<p:sldMasterIdLst><p:sldMasterId id=\"2147483648\" r:id=\"" & masterId & "\"/></p:sldMasterIdLst>" &
    (if slideIds.len > 0: "<p:sldIdLst>" & slideIds & "</p:sldIdLst>" else: "") &
    "<p:sldSz cx=\"" & $p.width & "\" cy=\"" & $p.height & "\"/><p:notesSz cx=\"6858000\" cy=\"9144000\"/>" &
    "<p:defaultTextStyle>" & textStyle & "</p:defaultTextStyle></p:presentation>")

proc toPptx*(p: Presentation): string = p.toPackage.toZip
  ## The bytes of the .pptx file.

proc save*(p: Presentation, path: string) = writeFile(path, p.toPptx)
  ## Writes the .pptx file.
