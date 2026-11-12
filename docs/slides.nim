## The blocks only xoffy's pages have: a deck shown as the slides LibreOffice draws of it, the XML
## inside a deck, and the parts of a package as a table.
##
##   nbSlides deck, "hello"          # writes docs/files/hello.pptx, shows its slides, links the file
##   nbXml deck, "ppt/slides/slide1.xml", "the slide"   # one part, indented and highlighted, folded
##   nbPackage deck                  # every part of the package: name, content type, size
##
## The slides are drawn at build time: the deck goes to PDF with LibreOffice (`soffice`), each page
## to a PNG with poppler (`pdftoppm`). A deck that did not change is not drawn again: its pictures
## are kept beside a stamp with the hash of its bytes. Without LibreOffice, the page says so and
## links the file.

import std/[os, osproc, strutils, strformat, hashes, algorithm, sequtils, json]
import nimib
import tabelline, tabelline/nimib
import xoffy, xoffy/[opc, zip, xml]
import blocks

const filesDir* = currentSourcePath().parentDir / "files"
  ## `docs/files/`: the decks the pages write, and their pictures (built, not committed)

proc fileHref(name, pageFile: string): string =
  relativePath(filesDir / name, absolutePath(pageFile).parentDir).replace('\\', '/')

proc drawDeck*(bytes, name: string): seq[string] =
  ## Writes `docs/files/<name>.pptx` and the PNG of each of its slides, and returns the PNGs'
  ## names. Skipped when the stamp says these bytes were drawn already.
  createDir filesDir
  let deckFile = filesDir / name & ".pptx"
  let stamp = filesDir / name & ".stamp"
  let h = $hash(bytes)
  proc pngs(): seq[string] =
    for f in walkFiles(filesDir / name & "-*.png"): result.add f.extractFilename
    result.sort(proc (a, b: string): int = cmp(a.len, b.len) * 10 + cmp(a, b))
  if fileExists(stamp) and readFile(stamp) == h and fileExists(deckFile) and pngs().len > 0:
    return pngs()
  writeFile(deckFile, bytes)
  for f in pngs(): removeFile(filesDir / f)
  if findExe("soffice").len == 0 or findExe("pdftoppm").len == 0: return @[]
  let tmp = getTempDir() / "xoffy-draw-" & name
  createDir tmp
  let (o1, c1) = execCmdEx(&"soffice --headless --convert-to pdf --outdir {quoteShell(tmp)} {quoteShell(deckFile)}")
  if c1 != 0: (echo o1; return @[])
  let (o2, c2) = execCmdEx(&"pdftoppm -png -r 90 {quoteShell(tmp / name & \".pdf\")} {quoteShell(filesDir / name)}")
  if c2 != 0: (echo o2; return @[])
  removeDir tmp
  writeFile(stamp, h)
  pngs()

newNbBlock(NbSlides):
  deckHref: string
  deckName: string
  pngHrefs: seq[string]
  small: bool
  caption: string
  toHtml:
    var imgs = ""
    for k, src in blk.pngHrefs:
      imgs.add &"""<img src="{src}" alt="Slide {k + 1} of {blk.deckName}.pptx, as LibreOffice draws it">"""
    let drawn = if blk.pngHrefs.len > 0: "drawn by LibreOffice" else: "LibreOffice was not there to draw it"
    let cap = (if blk.caption.len > 0: markdownToHtml(blk.caption).strip.replace("<p>", "").replace("</p>", "") & " · " else: "")
    &"""<figure class="deck{(if blk.small: " small" else: "")}"><div class="slides">{imgs}</div>""" &
      &"""<figcaption>{cap}<a href="{blk.deckHref}" download>{blk.deckName}.pptx</a>, {drawn}</figcaption></figure>"""

proc addSlides*(nb: var Nb, p: Presentation, name: string, caption = "", small = false) =
  let pngs = drawDeck(p.toPptx, name)
  nb.add newNbSlides(deckHref = fileHref(name & ".pptx", nb.doc.filename), deckName = name,
                     pngHrefs = pngs.mapIt(fileHref(it, nb.doc.filename)), small = small, caption = caption)

template nbSlides*(p: Presentation, name: string, caption = "", small = false) =
  ## The deck `p`: its slides as pictures, one under the other (`small`: side by side), and a
  ## link to the .pptx file. `name` names the file, `docs/files/<name>.pptx`.
  nb.addSlides(p, name, caption, small)

# ------------------------------------------------------------------------------------- the XML

proc indentXml*(x: string, width = 2): string =
  ## One element per line, indented; text stays on the line of its element.
  var depth = 0
  var i = 0
  var s = x
  if s.startsWith("<?xml"): s = s[s.find("?>") + 2 .. ^1].strip
  while i < s.len:
    if s[i] == '<':
      let e = s.find('>', i)
      let t = s[i .. e]
      let closing = t.startsWith("</")
      let selfClosing = t.endsWith("/>")
      if closing: dec depth
      # an element whose content is only text: keep it on one line
      if not closing and not selfClosing:
        let nextLt = s.find('<', e + 1)
        if nextLt > e + 1 and s.continuesWith("</", nextLt):
          let close = s.find('>', nextLt)
          result.add repeat(' ', depth * width) & s[i .. close] & "\n"
          i = close + 1
          continue
      result.add repeat(' ', depth * width) & t & "\n"
      if not closing and not selfClosing: inc depth
      i = e + 1
    else:
      let nextLt = s.find('<', i)
      let stop = if nextLt < 0: s.len else: nextLt
      let text = s[i ..< stop].strip
      if text.len > 0: result.add repeat(' ', depth * width) & text & "\n"
      i = stop
  result.stripLineEnd

newNbBlock(NbXml):
  label: string
  part: string
  xml: string
  open: bool
  toHtml:
    let lines = blk.xml.countLines
    let label = if blk.label.len > 0 and blk.label != blk.part: esc(blk.label) else: "<code>" & esc(blk.part) & "</code>"
    &"""<details class="foldcode"{(if blk.open: " open" else: "")}><summary>{label}<span>{lines} lines</span></summary>""" &
      &"""<pre><code class="nohighlight xml hljs">{highlightXml(blk.xml)}</code></pre></details>"""

proc addXml*(nb: var Nb, xml, part, label: string, open = false) =
  nb.add newNbXml(label = label, part = part, xml = indentXml(xml), open = open)

template nbXml*(p: Presentation, part: string, label = "the XML", open = false) =
  ## One part of the deck `p`, indented and highlighted, folded under `label`.
  nb.addXml(readZip(p.toPptx)[part], part, label, open)

template nbXmlText*(xml: string, label = "the XML", part = "", open = false) =
  ## Some XML, indented and highlighted, folded under `label`.
  nb.addXml(xml, part, label, open)

# ------------------------------------------------------------------------------- the package

proc packageTable*(bytes: string, title = ""): Tabella =
  ## The parts of the package in `bytes`, in the order of the zip: name, what it is, size.
  let files = readZip(bytes)
  let pkg = readPackage(bytes)
  var names, kinds: seq[string]
  var sizes: seq[int]
  for name, data in files:
    names.add name
    sizes.add data.len
    let i = pkg.find(name)
    var kind = if i >= 0: pkg.parts[i].contentType else: (if name.endsWith(".rels"): "relationships" else: "content types")
    for pre in ["application/vnd.openxmlformats-officedocument.presentationml.", "application/vnd.openxmlformats-officedocument.",
                "application/vnd.openxmlformats-package.", "application/"]:
      kind.removePrefix(pre)
    kind.removeSuffix("+xml")
    kinds.add kind
  let data = tableData:
    part: names
    kind: kinds
    bytes: sizes
  tabella(data):
    tabHeader title
    colsLabel:
      kind: "content type"
    fmtInteger "bytes"
    optCssTheme()

template nbPackage*(p: Presentation, title = "") =
  ## Every part of the deck `p`, as a table.
  nbTable packageTable(p.toPptx, title)
