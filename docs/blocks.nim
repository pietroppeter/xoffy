## The blocks of xoffy's pages, and the page itself (header, footer, headings). Copied from
## tabelline's docs/blocks.nim (the Munari look shared by Pietro's libraries), with the blocks
## of xoffy's own: `nbSlides` (a deck, as the pictures LibreOffice draws of it) and `nbXml`.
##
## A page says what it shows with these blocks, and never how it is drawn: no HTML in `nbText`,
## no CSS and no colours in a page. The CSS of every block is in `theme.nim`, from the tokens.
##
##   nb.useXoffy(section = "...", title = "...")   # right after nbInit
##   nbTitle "kicker", "Title", "a lede, in Markdown"
##   nbToc
##   nbNote "text", nkWarning
##   nbCards: (nbCard "Title", "href/": nbText "...")
##   nbGallery "what it shows": (nbGalleryCard "Title": ...)
##   nbTabs python, r: (nbCode ...)            # Nim, next to Python and R
##   nbShowCode: (nbTable t)                   # the table, with its code folded under it
##   nbFoldCode "docs/review.nim"              # a source file, or a part of it, folded
##   nbShowR "gt(...)"; runR "story/gt.json"   # a gt table made in R, its code folded under it
##   nbParts t                                 # a table and its parts, with a switch
##   nbSwatches [("--primary", "primary", "sections")]
##
## A block is made with `newNbBlock`; a container (`of NbContainer`) holds other blocks, opened
## with `nb.withContainer`. Template parameters are named apart from the fields they fill.

import std/[json, os, osproc, strutils, strformat, sequtils, base64]
import nimib
import tabelline, tabelline/nimib
import theme, review
export theme

const
  repoUrl* = "https://github.com/pietroppeter/xoffy"
  siteUrl* = "https://pietroppeter.github.io/xoffy/"

func esc(s: string): string = s.multiReplace(("&", "&amp;"), ("<", "&lt;"), (">", "&gt;"), ("\"", "&quot;"))
func inline(md: string): string =
  ## Markdown for one line: the text without its paragraph.
  markdownToHtml(md).strip.replace("<p>", "").replace("</p>", "")

# ----------------------------------------------------------------------------- headings and TOC

func slugify*(s: string): string =
  ## The anchor of a heading: lowercase words joined by `-`.
  var last = '-'
  for c in s.toLowerAscii:
    if c in {'a'..'z', '0'..'9'}:
      result.add c
      last = c
    elif last != '-':
      result.add '-'
      last = '-'
  result = result.strip(chars = {'-'})

func stripInline(s: string): string =
  ## Heading text without Markdown marks or tags, for anchors and the indice.
  var inTag = false
  for c in s:
    if c == '<': inTag = true
    elif c == '>': inTag = false
    elif not inTag and c notin {'*', '`', '_'}: result.add c

func headingsOf*(markdownText: string): seq[(int, string)] =
  ## The `##` and `###` headings of a Markdown text, with their level (outside code fences).
  var fence = false
  for line in markdownText.splitLines:
    if line.strip.startsWith("```"): fence = not fence
    if fence: continue
    if line.startsWith("## "): result.add (2, line[3 .. ^1].strip.stripInline)
    elif line.startsWith("### "): result.add (3, line[4 .. ^1].strip.stripInline)

func addHeadingIds(html: string, su = false): string =
  ## `<h2>Text</h2>` becomes `<h2 id="text">Text</h2>`: an id matching `slugify` of the indice.
  ## With `su` (a page with an indice), also a way back to it: `<a class="su" href="#indice"></a>`.
  result = html
  for tag in ["h2", "h3"]:
    var res = ""
    var i = 0
    let open = "<" & tag & ">"
    let close = "</" & tag & ">"
    while true:
      let a = result.find(open, i)
      if a < 0: break
      let b = result.find(close, a)
      if b < 0: break
      let inner = result[a + open.len ..< b]
      # an arrow back to the indice, only on pages that have one; drawn by CSS, so the heading's
      # text stays the same for anchors and quotes
      res.add result[i ..< a] & "<" & tag & " id=\"" & slugify(stripInline(inner).replace("&amp;", "&")) & "\">" & inner &
        (if su: "<a class=\"su\" href=\"#indice\" aria-label=\"Back to the contents\"></a>" else: "") & close
      i = b + close.len
    res.add result[i .. ^1]
    result = res

# --------------------------------------------------------------------------------- highlighting

func unescapeHtml(s: string): string =
  s.multiReplace(("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&"))

const
  pythonKeywords = ["and", "as", "assert", "break", "class", "continue", "def", "del", "elif", "else",
    "except", "finally", "for", "from", "global", "if", "import", "in", "is", "lambda", "not", "or",
    "pass", "raise", "return", "try", "while", "with", "yield"]
  jsKeywords = ["var", "let", "const", "function", "return", "if", "else", "for", "while", "new",
    "typeof", "in", "of", "try", "catch", "break", "continue", "this"]
  rKeywords = ["if", "else", "for", "while", "repeat", "function", "return", "next", "break", "in",
    "library", "require"]
  otherLiterals = ["True", "False", "None", "TRUE", "FALSE", "NULL", "NA", "Inf", "NaN"]
  jsLiterals = ["true", "false", "null", "undefined", "Infinity"]

func highlightOther*(code, lang: string): string =
  ## A small highlighter for the R, Python, JavaScript (and YAML) code that pages show but do not
  ## run: keywords, strings, numbers, comments and function calls, with the classes of the Nim code.
  let keywords = if lang == "r": @rKeywords elif lang == "python": @pythonKeywords
                 elif lang == "js": @jsKeywords else: @[]
  let literals = if lang == "js": @jsLiterals else: @otherLiterals
  let comment = if lang == "js": "//" else: "#"
  func span(cls, s: string): string = "<span class=\"hljs-" & cls & "\">" & esc(s) & "</span>"
  var i = 0
  while i < code.len:
    let c = code[i]
    if code.continuesWith(comment, i):
      var j = i
      while j < code.len and code[j] != '\n': inc j
      result.add span("comment", code[i ..< j]); i = j
    elif c in {'"', '\''}:
      var j = i + 1
      while j < code.len and code[j] != c and code[j] != '\n':
        if code[j] == '\\': inc j
        inc j
      j = min(j + 1, code.len)
      result.add span("string", code[i ..< j]); i = j
    elif c in {'0'..'9'} and (i == 0 or code[i - 1] notin {'a'..'z', 'A'..'Z', '_', '.'}):
      var j = i
      while j < code.len and code[j] in {'0'..'9', '.', '_', 'e', 'E', 'x', 'L'}: inc j
      result.add span("number", code[i ..< j]); i = j
    elif c in {'a'..'z', 'A'..'Z', '_', '.'}:
      var j = i
      while j < code.len and code[j] in {'a'..'z', 'A'..'Z', '0'..'9', '_', '.', '-'}: inc j
      let w = code[i ..< j]
      if w in keywords: result.add span("keyword", w)
      elif w in literals: result.add span("literal", w)
      elif lang == "yaml" and j < code.len and code[j] == ':': result.add span("keyword", w)
      elif j < code.len and code[j] == '(' and w.strip(chars = {'.'}).len > 0:
        let lead = w.len - w.strip(leading = true, trailing = false, chars = {'.'}).len
        result.add esc(w[0 ..< lead]) & span("built_in", w[lead .. ^1])
      else: result.add esc(w)
      i = j
    elif c == '|' and i + 1 < code.len and code[i + 1] == '>':
      result.add span("meta", "|>"); i += 2
    else:
      result.add esc($c); inc i

func highlightXml*(code: string): string =
  ## XML, highlighted: element names as keywords, attribute names as attributes, values as strings.
  func span(cls, s: string): string = "<span class=\"hljs-" & cls & "\">" & esc(s) & "</span>"
  var i = 0
  while i < code.len:
    if code[i] == '<':
      var j = i + 1
      while j < code.len and code[j] notin {' ', '>', '/', '\n'} or (j == i + 1 and code[j] in {'/', '?'}): inc j
      result.add span("keyword", code[i ..< j])
      i = j
      while i < code.len and code[i] != '>':
        if code[i] == '"':
          let e = code.find('"', i + 1)
          let stop = if e < 0: code.high else: e
          result.add span("string", code[i .. stop]); i = stop + 1
        elif code[i] in {'a'..'z', 'A'..'Z', ':', '_'}:
          var k = i
          while k < code.len and code[k] in {'a'..'z', 'A'..'Z', '0'..'9', ':', '_', '-'}: inc k
          result.add span("attr", code[i ..< k]); i = k
        else:
          result.add esc($code[i]); inc i
      if i < code.len: (result.add span("keyword", ">"); inc i)
    else:
      result.add esc($code[i]); inc i

func highlightFences(html: string): string =
  ## Code fences in Markdown, highlighted like the code that ran: Nim with nimib's highlighter,
  ## R, Python, JavaScript and YAML with `highlightOther`, shell with its comments.
  result = html
  for lang in ["nim", "r", "python", "js", "yaml", "sh", "xml"]:
    let openTag = "<pre><code class=\"language-" & lang & "\">"
    const close = "</code></pre>"
    var res = ""
    var i = 0
    while true:
      let a = result.find(openTag, i)
      if a < 0: break
      let b = result.find(close, a + openTag.len)
      if b < 0: break
      let code = unescapeHtml(result[a + openTag.len ..< b]).strip(leading = false, chars = {'\n'})
      res.add result[i ..< a]
      res.add "<pre><code class=\"nohighlight " & lang & " hljs\">" &
        (if lang == "nim": highlightNim(code) elif lang == "xml": highlightXml(code) else: highlightOther(code, lang)) & close
      i = b + close.len
    res.add result[i .. ^1]
    result = res

func codeHtml*(code, lang: string): string =
  ## Code that is shown, not run (Python, R and YAML examples), highlighted.
  "<pre><code class=\"nohighlight " & lang & " hljs\">" & highlightOther(code.strip(chars = {'\n'}), lang) & "</code></pre>"

# ------------------------------------------------------------------------------------- the title

newNbBlock(NbTitle):
  kicker: string
  title: string
  lede: string
  toHtml:
    (if blk.kicker.len > 0: &"""<p class="kicker">{inline(blk.kicker)}</p>""" & "\n" else: "") &
      &"<h1>{inline(blk.title)}</h1>\n" &
      (if blk.lede.len > 0: &"""<div class="lede">{markdownToHtml(blk.lede)}</div>""" else: "")

proc addTitle*(nb: var Nb, kicker, title: string, lede = "") =
  nb.add newNbTitle(kicker = kicker, title = title, lede = lede)

template nbTitle*(tkicker, ttitle: string, tlede = "") =
  ## The top of a page: a small line above (the kicker: what kind of page, a date), the title,
  ## and the lede, a paragraph that says what the page is for. All three in Markdown.
  nb.addTitle(tkicker, ttitle, tlede)

# ------------------------------------------------------------------------------ parts of a page

type PartRole* = enum
  ## The colour of a part of a page: its sections' circles and their entries in the indice.
  prPrimary = "primary", prSecondary = "secondary", prSuccess = "success"

newNbBlock(NbPart):
  numero: int
  title: string
  role: PartRole
  toHtml:
    if blk.title == "": &"""<p class="parte parte-{blk.role}" hidden></p>"""   # colour only, no label
    else: &"""<p class="parte parte-{blk.role}">Part {blk.numero} · {inline(blk.title)}</p>"""

proc addPart*(nb: var Nb, num: int, title: string, role: PartRole) =
  nb.add newNbPart(numero = num, title = title, role = role)

template nbPart*(tnum: int, ttitle: string, trole: PartRole) =
  ## The start of a part of a long page: a label, and from here on the sections' circles (and
  ## their entries in the indice) take the colour of `trole`. With an empty title there is no
  ## label, only the colour: for a page whose headings already name its parts.
  nb.addPart(tnum, ttitle, trole)

# ------------------------------------------------------------------------------------ the indice

newNbBlock(NbToc):
  title: string
  toHtml:
    var items = ""
    var openSub = false
    var part = ""
    for b in nb.doc.blocksFlattened:
      if b of NbPart: part = &""" class="parte-{b.NbPart.role}""""
      if not (b of NbText): continue
      for (level, text) in headingsOf(b.NbText.text):
        let link = &"""<a href="#{slugify(text)}">{text}</a>"""
        if level == 2:
          if openSub: (items.add "</ol>"; openSub = false)
          if items.len > 0: items.add "</li>"
          items.add &"<li{part}>" & link
        else:
          if not openSub: (items.add "<ol>"; openSub = true)
          items.add "<li>" & link & "</li>"
    if openSub: items.add "</ol>"
    if items.len > 0: items.add "</li>"
    &"""<nav class="indice" id="indice" aria-label="{blk.title}"><h2 class="indice-title">{blk.title}</h2><ol>{items}</ol></nav>"""

proc addToc*(nb: var Nb, title = "Indice") =
  nb.doc.context["indice"] = %true   # the headings get their arrow back to it (`addHeadingIds`)
  nb.add newNbToc(title = title)

template nbToc*(ttitle = "Indice") =
  ## The table of contents of the page's `##` and `###` headings, built when the page is saved.
  nb.addToc(ttitle)

# ----------------------------------------------------------------------------------------- notes

type NoteKind* = enum
  ## What a note is about; its colour follows (`theme.nim`). A warning carries the triangle.
  nkPlain = "plain"      ## an aside
  nkInfo = "info"        ## information, a page to go to
  nkDone = "done"        ## what is done, what works
  nkMissing = "missing"  ## what is missing, or differs from gt and Great Tables
  nkWarning = "warning"  ## something to watch out for: the API will change, a step breaks things
  nkCode = "code"        ## about the code: what xoffy does in the slide above, and why

newNbBlock(NbNote):
  text: string
  tipo: NoteKind
  title: string
  toHtml:
    &"""<div class="nota {blk.tipo}">""" &
      (if blk.title.len > 0: &"""<span class="titolo">{inline(blk.title)}</span>""" else: "") &
      markdownToHtml(blk.text) & "</div>"

proc addNote*(nb: var Nb, text: string, kind = nkPlain, title = "") =
  nb.add newNbNote(text = text, tipo = kind, title = title)

template nbNote*(ttext: string, tkind = nkPlain, ttitle = "") =
  ## A note beside the text, in Markdown, of a kind: `nbNote "The API will change.", nkWarning`.
  nb.addNote(ttext, tkind, ttitle)

# ----------------------------------------------------------------------------------------- cards

newNbBlock(NbCards of NbContainer):
  label: string
  toHtml:
    &"""<div class="cards" role="list" aria-label="{blk.label}">""" & nbContainerToHtml(blk, nb) & "</div>"

newNbBlock(NbCard of NbContainer):
  title: string
  href: string
  numero: string
  tipo: NoteKind
  toHtml:
    let title = if blk.href.len > 0: &"""<a href="{blk.href}">{inline(blk.title)}</a>""" else: inline(blk.title)
    &"""<div class="nota {blk.tipo}" role="listitem">""" &
      (if blk.numero.len > 0: &"""<span class="numero">{blk.numero}</span>""" else: "") &
      &"""<span class="titolo">{title}</span>""" & nbContainerToHtml(blk, nb) & "</div>"

template nbCards*(what: string, body: untyped) =
  ## A grid of cards (`nbCard`), such as the pages on the home page.
  let cards = newNbCards(label = what)
  nb.withContainer(cards):
    body
  nb.add cards

template nbCard*(heading, link, num: string, kind: NoteKind, body: untyped) =
  ## A card: a title (a link when `link` is not empty), a small number above it (or ""), a kind
  ## (`nkInfo` for a page to go to) and blocks inside.
  let card = newNbCard(title = heading, href = link, numero = num, tipo = kind)
  nb.withContainer(card):
    body
  nb.add card

template nbCard*(heading, link, num: string, body: untyped) =
  ## A card of kind `nkInfo`.
  nbCard(heading, link, num, nkInfo, body)

template nbCard*(heading: string, body: untyped) =
  ## A card with a title only.
  nbCard(heading, "", "", nkInfo, body)

# --------------------------------------------------------------------------------------- gallery

newNbBlock(NbGallery of NbContainer):
  label: string
  toHtml:
    &"""<div class="nb-galleria" tabindex="0" aria-label="{blk.label}">""" & nbContainerToHtml(blk, nb) & "</div>"

newNbBlock(NbGalleryCard of NbContainer):
  title: string
  label: string
  toHtml:
    let label = if blk.label.len > 0: &""" data-label="{esc(blk.label)}"""" else: ""
    &"""<div class="nb-scheda"{label}><h3>{inline(blk.title)}</h3>""" & nbContainerToHtml(blk, nb) & "</div>"

newNbBlock(NbBeside of NbContainer):
  toHtml:
    """<div class="accanto">""" & nbContainerToHtml(blk, nb) & "</div>"

template nbBeside*(body: untyped) =
  ## The blocks of `body` side by side, wrapping on a narrow screen: small tables to compare.
  let accanto = newNbBeside()
  nb.withContainer(accanto):
    body
  nb.add accanto

proc placeBeside*(c: NbContainer) =
  ## Puts tables that follow each other in `c` side by side (in an `NbBeside`).
  var res: seq[NbBlock]
  var i = 0
  while i < c.blocks.len:
    var j = i
    while j < c.blocks.len and c.blocks[j] of NbTable: inc j
    if j - i >= 2:
      let a = newNbBeside()
      a.blocks = c.blocks[i ..< j]
      res.add a
      i = j
    else:
      res.add c.blocks[i]
      inc i
  c.blocks = res

template nbGallery*(what: string, body: untyped) =
  ## A gallery: cards (`nbGalleryCard`) side by side, to swipe or scroll sideways, numbered.
  ## `what` says what it shows, for screen readers.
  let galleria = newNbGallery(label = what)
  nb.withContainer(galleria):
    body
  nb.add galleria

template nbGalleryCard*(heading: string, body: untyped) =
  ## A card of a gallery: a title and any blocks.
  nbGalleryCard(heading, "", body)

template nbGalleryCard*(heading, what: string, body: untyped) =
  ## A card of a gallery with a label before its number (a step, a part).
  let scheda = newNbGalleryCard(title = heading, label = what)
  nb.withContainer(scheda):
    body
  nb.add scheda

# ------------------------------------------------------------------------------------------ tabs

const languages* = [("nim", "👑 Nim"), ("python", "🐍 Python"), ("r", "🏴‍☠️ R")]

newNbBlock(NbTabs of NbContainer):
  python: string
  r: string
  toHtml:
    var nimCode, made = ""   # the Nim code goes in its tab; what it makes (a table) stays under the tabs
    for b in blk.blocks:
      if b of NbCode: nimCode.add nb.render(b).strip & "\n"
      else: made.add nb.render(b).strip & "\n"
    let panels = [nimCode.strip, (if blk.python.len > 0: codeHtml(blk.python, "python") else: ""),
                  (if blk.r.len > 0: codeHtml(blk.r, "r") else: "")]
    var res = """<div class="languages"><div class="lingue-tab" role="tablist">"""
    var first = true
    for i, (key, label) in languages:
      if panels[i].len == 0: continue
      res.add &"""<button type="button" role="tab" data-lingua="{key}" aria-selected="{first}">{label}</button>"""
      first = false
    res.add "</div>"
    first = true
    for i, (key, label) in languages:
      if panels[i].len == 0: continue
      res.add &"""<div class="lingue-pannello" role="tabpanel" data-lingua="{key}"{(if first: "" else: " hidden")}>{panels[i]}</div>"""
      first = false
    res & "</div>" & made.strip

func tabsBlock(py, rr: string): NbTabs = newNbTabs(python = py, r = rr)

template nbTabs*(python, r: string, body: untyped) =
  ## The Nim blocks `body` adds (code that runs, and its output), in a 👑 Nim tab next to the
  ## same example in 🐍 Python (Great Tables) and 🏴‍☠️ R (gt), shown and not run. The tab picked
  ## holds for the whole page. Only the code changes with the tab: what the Nim makes (a table,
  ## any block that is not code) is shown under the tabs, whichever is picked.
  let tabs = tabsBlock(python, r)   # a proc: the parameters share the fields' names
  nb.withContainer(tabs):
    body
  nb.add tabs

# ------------------------------------------------------------------------------------- show code

newNbBlock(NbShowCode of NbContainer):
  code: string
  toHtml:
    nbContainerToHtml(blk, nb) & """<details class="codice"><summary></summary><pre><code class="nohighlight nim hljs">""" &
      highlightNim(blk.code) & "</code></pre></details>"

template nbShowCode*(body: untyped) =
  ## Runs `body` and shows the blocks it adds (its tables), with `body`'s own code folded below
  ## them: "show code" opens it.
  let showCode = newNbShowCode(code = getCode(body))
  nb.withContainer(showCode):
    block:
      body
  nb.add showCode

# ---------------------------------------------------------------------------------- code, folded
# A source file, or a part of it, folded under its name and its length: a page can show the code it
# talks about without its length getting in the way. Several in a row make a list. nimib's
# `nbFile` shows a file too, always open.

const repoRoot = currentSourcePath().parentDir.parentDir

newNbBlock(NbFoldCode):
  title: string
  path: string
  lang: string
  code: string
  toHtml:
    let lines = blk.code.splitLines.len
    let name = if blk.title.len > 0: inline(blk.title) else: "<code>" & esc(blk.path) & "</code>"
    &"""<details class="foldcode"><summary>{name} <span>{lines} lines</span></summary>""" &
      (if blk.lang == "nim": "<pre><code class=\"nohighlight nim hljs\">" & highlightNim(blk.code) & "</code></pre>"
       else: codeHtml(blk.code, blk.lang)) & "</details>"

proc langOf(file: string): string =
  case file.splitFile.ext
  of ".nim", ".nims": "nim"
  of ".py": "python"
  of ".R", ".r": "r"
  of ".js": "js"
  of ".yaml", ".yml": "yaml"
  else: "sh"

proc foldCode*(nb: var Nb, file: string, start = "", stop = "", title = "", lang = "") =
  ## `file` (a path from the root of the repository, or any path), folded. With `start`, from the
  ## first line that holds it; with `stop`, up to the next line that holds that (or to the end).
  let path = if fileExists(file): file else: repoRoot / file
  var code = readFile(path)
  if start.len > 0:
    let i = code.find(start)
    doAssert i >= 0, file & ": no " & start
    code = code[code.rfind('\n', last = i) + 1 .. ^1]
    if stop.len > 0:
      let j = code.find(stop, start = code.find('\n') + 1)
      if j >= 0: code = code[0 ..< code.rfind('\n', last = j) + 1]
  nb.add newNbFoldCode(title = title, path = relativePath(absolutePath(path), repoRoot), lang = (if lang.len > 0: lang else: langOf(file)),
                       code = code.dedent.strip(chars = {'\n'}))

template nbFoldCode*(file: string, start = "", stop = "", title = "", lang = "") =
  ## Code folded under its path (or `title`, in Markdown) and its length:
  ## `nbFoldCode "docs/review.nim"`, or a part of it with `start` and `stop`.
  nb.foldCode(file, start, stop, title, lang)

# -------------------------------------------------------------------------------------- swatches

newNbBlock(NbSwatches):
  tinte: seq[(string, string, string)]
  toHtml:
    var res = """<div class="tinte">"""
    for (colour, name, what) in blk.tinte:
      let css = if colour.startsWith("--"): "var(" & colour & ")" else: colour
      res.add &"""<div class="tinta"><span style="background:{css}"></span><strong>{inline(name)}</strong>{inline(what)}</div>"""
    res & "</div>"

proc addSwatches*(nb: var Nb, swatches: openArray[(string, string, string)]) =
  nb.add newNbSwatches(tinte = @swatches)

template nbSwatches*(swatches: openArray[(string, string, string)]) =
  ## Swatches: a colour (a token such as `--primary`, or a CSS colour), its name and what it is
  ## for, in Markdown.
  nb.addSwatches(swatches)

# ---------------------------------------------------------------------------- annotated screens

newNbBlock(NbScreenshot):
  src: string
  alt: string
  punti: seq[(int, float, float)]
  toHtml:
    var marks = ""
    for (n, x, y) in blk.punti:
      marks.add &"""<span class="punto" style="left:{x:.1f}%;top:{y:.1f}%" aria-hidden="true">{n}</span>"""
    &"""<figure class="schermata"><div><img src="{blk.src}" alt="{esc(blk.alt)}">{marks}</div>""" &
      &"""<figcaption>{inline(blk.alt)}</figcaption></figure>"""

proc addScreenshot*(nb: var Nb, image, points, alt: string) =
  let j = parseJson(readFile(points))
  var punti: seq[(int, float, float)]
  for p in j["points"]: punti.add (p["n"].getInt, p["x"].getFloat, p["y"].getFloat)
  let mime = if image.endsWith(".png"): "image/png" else: "image/jpeg"
  nb.add newNbScreenshot(src = "data:" & mime & ";base64," & encode(readFile(image)), alt = alt, punti = punti)

template nbScreenshot*(timage, tpoints, talt: string) =
  ## A screenshot with numbered circles on it, to name its pieces in the text or a table: the
  ## image (inlined), a JSON of points (`{"points": [{"n": 1, "x": 12.5, "y": 40}]}`, in % of the
  ## width and height) and a caption in Markdown. Put two side by side with `nbBeside`.
  nb.addScreenshot(timage, tpoints, talt)

newNbBlock(NbDrawing):
  svg: string
  alt: string
  toHtml:
    &"""<figure class="disegno" role="img" aria-label="{esc(blk.alt)}">{blk.svg}<figcaption>{inline(blk.alt)}</figcaption></figure>"""

proc addDrawing*(nb: var Nb, svgFile, alt: string) =
  nb.add newNbDrawing(svg = readFile(svgFile).strip, alt = alt)

template nbDrawing*(tsvg, talt: string) =
  ## A drawing made elsewhere (a diagram drawn by Pele, with diagrammari), as an SVG file: inlined,
  ## in the page's colours, with a caption in Markdown.
  nb.addDrawing(tsvg, talt)

# ------------------------------------------------------------------------------------ a fold

newNbBlock(NbFold of NbContainer):
  label: string
  toHtml:
    &"""<details class="fold"><summary>{inline(blk.label)}</summary>""" & nbContainerToHtml(blk, nb) & "</details>"

template nbFold*(tlabel: string, body: untyped) =
  ## A part of a page folded under a line in Markdown, closed at first: a long list a reader
  ## opens when they need it, such as a module of the API reference. A link to something inside
  ## it (`#name`) opens it.
  let fold = newNbFold(label = tlabel)
  nb.withContainer(fold):
    body
  nb.add fold

# ------------------------------------------------------------------------------- the API reference

type ApiLink* = object
  ## A link under an API entry: what it is (`gt`, `source`), its text and where it goes.
  label*, text*, href*: string

newNbBlock(NbApi):
  name: string
  anchor: string
  alias: string
  symKind: string
  signatures: seq[string]
  doc: string
  links: seq[ApiLink]
  exampleCode: string
  exampleHtml: string
  toHtml:
    var s = &"""<section class="api" id="{blk.anchor}">""" &
      (if blk.alias.len > 0: &"""<span class="api-alias" id="{blk.alias}"></span>""" else: "") &
      &"""<h4><code>{esc(blk.name)}</code><span class="api-kind">{blk.symKind}</span>""" &
      &"""<a class="api-anchor" href="#{blk.anchor}" title="a link to {esc(blk.name)}, to copy">#</a></h4>"""
    for sig in blk.signatures:
      s.add "<pre class=\"api-sig\"><code class=\"nohighlight nim hljs\">" & highlightNim(sig) & "</code></pre>"
    s.add(if blk.doc.len > 0: highlightFences(markdownToHtml(blk.doc))
          else: """<p class="api-none">No doc comment yet.</p>""")
    if blk.exampleCode.len > 0:
      s.add """<details class="api-ex"><summary>an example, from the specs</summary>""" &
        "<pre><code class=\"nohighlight nim hljs\">" & highlightNim(blk.exampleCode) & "</code></pre>" &
        blk.exampleHtml & "</details>"
    if blk.links.len > 0:
      s.add """<p class="api-links">"""
      for i, l in blk.links:
        if i > 0: s.add " · "
        s.add &"""{l.label} <a href="{l.href}">{inline(l.text)}</a>"""
      s.add "</p>"
    s & "</section>"

template nbApi*(tname, tanchor, talias, tkind: string, tsignatures: seq[string], tdoc: string,
                tlinks: seq[ApiLink] = @[], texampleCode = "", texampleHtml = "") =
  ## One name of the API: its kind (proc, template, type...), its signatures (one per overload,
  ## highlighted), its doc comment in Markdown (or a line that says there is none yet), an
  ## example folded under it (code, and the table it makes) and links (gt's name, the source).
  ## `tanchor` is its `id`, for links from outside (`#verbs-tabHeader`); `talias`, when not
  ## empty, a second, shorter one (`#tabHeader`).
  nb.add newNbApi(name = tname, anchor = tanchor, alias = talias, symKind = tkind, signatures = tsignatures, doc = tdoc,
                  links = tlinks, exampleCode = texampleCode, exampleHtml = texampleHtml)

# ------------------------------------------------------------------------------------- the page

const temaHeadScript = """<script>
(function () {
  try {
    var q = new URLSearchParams(location.search).get('tema');
    if (q === 'munari' || q === 'quaderno') localStorage.setItem('xoffy-tema', q);
    var t = q || localStorage.getItem('xoffy-tema');
    document.documentElement.dataset.tema = (t === 'quaderno') ? 'quaderno' : 'munari';
  } catch (e) { document.documentElement.dataset.tema = 'munari'; }
})();
</script>"""

# What the blocks do in the browser: the look switch, the language tabs, the parts switch, and
# the filter of the specs page.
const bodyScript = """<script>
(function () {
  var root = document.documentElement;
  function show() {
    var t = root.dataset.tema === 'quaderno' ? 'quaderno' : 'munari';
    document.querySelectorAll('.tema button').forEach(function (b) {
      b.setAttribute('aria-pressed', b.dataset.tema === t ? 'true' : 'false');
    });
  }
  document.querySelectorAll('.tema button').forEach(function (b) {
    b.addEventListener('click', function () {
      root.dataset.tema = b.dataset.tema;
      try { localStorage.setItem('xoffy-tema', b.dataset.tema); } catch (e) {}
      show();
    });
  });
  show();
  function choose(lang) {
    document.querySelectorAll('.lingue').forEach(function (box) {
      if (!box.querySelector('[data-lingua="' + lang + '"]')) return;
      box.querySelectorAll('.lingue-tab button').forEach(function (b) { b.setAttribute('aria-selected', b.dataset.lingua === lang ? 'true' : 'false'); });
      box.querySelectorAll('.lingue-pannello').forEach(function (p) { p.hidden = p.dataset.lingua !== lang; });
    });
  }
  document.querySelectorAll('.lingue-tab button').forEach(function (b) {
    b.addEventListener('click', function () { choose(b.dataset.lingua); });
  });
  document.querySelectorAll('.mostra-parti').forEach(function (b) {
    var d = b.nextElementSibling, p = d.nextElementSibling;
    b.addEventListener('click', function () {
      var on = b.getAttribute('aria-pressed') !== 'true';
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
      b.textContent = on ? 'Show the data' : 'Show the parts';
      d.hidden = on; p.hidden = !on;
    });
  });
})();
(function () {
  // a link to something inside a closed fold (nbFold) opens the fold, then goes there
  function reveal() {
    var id = decodeURIComponent(location.hash.slice(1));
    var el = id && document.getElementById(id);
    if (!el) return;
    var shut = false;
    for (var d = el.closest('details.fold'); d; d = d.parentElement && d.parentElement.closest('details.fold')) {
      if (!d.open) { d.open = true; shut = true; }
    }
    if (shut) el.scrollIntoView();
  }
  window.addEventListener('hashchange', reveal);
  reveal();
})();
(function () {
  // the specs page: ?spec=a,b&change=c (or after #) shows only those, opened
  if (!document.getElementById("filterbar")) return;
  const params = new URLSearchParams(location.search || location.hash.slice(1));
  const want = { spec: [], change: [] };
  for (const k of ["spec", "change"]) for (const v of params.getAll(k)) want[k].push(...v.split(",").map(s => s.trim()).filter(Boolean));
  if (!want.spec.length && !want.change.length) return;
  const match = (name, list) => list.some(p => p === "all" || p === name || (p.endsWith("*") && name.startsWith(p.slice(0, -1))));
  const found = [];
  document.querySelectorAll("details.spec[data-spec]").forEach(d => {
    const ok = match(d.dataset.spec, want.spec); d.hidden = !ok; if (ok) { d.open = true; found.push(d.dataset.spec); } });
  document.querySelectorAll("details.change[data-change]").forEach(d => {
    const ok = match(d.dataset.change, want.change); d.hidden = !ok; if (ok) { d.open = true; found.push(d.dataset.change); } });
  if (!want.spec.length) document.getElementById("specs").hidden = true;
  if (!want.change.length) document.getElementById("open-changes").hidden = true;
  const bar = document.getElementById("filterbar");
  const missing = [...want.spec, ...want.change].filter(p => !p.endsWith("*") && p !== "all" && !found.includes(p));
  bar.innerHTML = "Showing only: <b>" + (found.join(", ") || "nothing") + "</b>" +
    (missing.length ? " · not found: " + missing.join(", ") : "") + ' · <a href="' + location.pathname + '">show everything</a>';
  bar.hidden = false;
})();
</script>"""

const temaSwitch = """<div class="tema" role="group" aria-label="Look of the page">
<button type="button" data-tema="munari" title="after Bruno Munari" aria-pressed="true">Munari</button><button type="button" data-tema="quaderno" title="an Italian school exercise book">quaderno</button>
</div>"""
const forme = """<div class="forme" aria-hidden="true"><i class="cerchio"></i><i class="quadrato"></i><i class="triangolo"></i></div>"""
const motto = """<p class="motto">“Complicare è facile, semplificare è difficile.” <span>Bruno Munari</span></p>"""

func pageText(blk: JsonNode, nb: Nb): string =
  highlightFences(addHeadingIds(markdownToHtml(blk{"text"}.getStr), nb.doc.context{"indice"}.getBool))

func pageHeader(blk: JsonNode, nb: Nb): string =
  let c = nb.doc.context
  let home = c{"home_href"}.getStr
  let backLabel = c{"back_label"}.getStr("xoffy")
  let back = if home.len > 0: &"""<a href="{home}">← {backLabel}</a>""" else: "<span></span>"
  var rows = ""
  # The masthead: the wordmark, the section and its cadence. The quaderno shows them as the label
  # of an exercise book, so each line keeps the label's word for it (Nome, Materia, Classe).
  for (key, label, cls) in [("wordmark", "Nome", "nome"), ("section", "Materia", ""), ("cadence", "Classe", "")]:
    let v = c{key}.getStr
    if v.len > 0:
      let wordmarkHref = c{"wordmark_href"}.getStr
      let shown = if key == "wordmark" and wordmarkHref.len > 0: &"""<a href="{wordmarkHref}">{v}</a>""" else: v
      rows.add &"""<div class="riga {cls}"><span>{label}</span><span>{shown}</span></div>"""
  &"""<header>
<nav class="crumbs">{back}<a href="{repoUrl}">xoffy on GitHub ↗</a></nav>
{temaSwitch}{forme}
<div class="etichetta">{rows}</div>
</header>"""

func pageFooter(blk: JsonNode, nb: Nb): string =
  let source = nb.doc.context{"source_highlighted"}.getStr
  "<footer>" & motto & "Written in Nim with <a href=\"https://github.com/pietroppeter/nimib\">nimib</a> 🐳 · " &
    &"""tables by <a href="https://github.com/pietroppeter/tabelline">tabelline</a>, slides by <a href="{repoUrl}">xoffy</a> · the code on this page ran when it was built""" &
    (if source.len == 0: "" else:
      """<details class="source"><summary>show the source of this page</summary><pre><code class="nohighlight nim">""" &
      source & "</code></pre></details>") & "</footer>" & bodyScript

func emptyPartial(blk: JsonNode, nb: Nb): string = ""

proc sharedReviewScript*(nb: Nb): string =
  ## The review mode's script for a page of the docs: the shared copy, `docs/assets/review.js`, or
  ## "" (inlined) with `-d:singleFile`. Pass it as `nbReview(..., tscript = sharedReviewScript(nb))`.
  when singleFile: "" else: assetHref("review.js", nb.doc.filename)

proc useXoffy*(nb: var Nb, section = "", cadence = "", title = "", description = "",
                   homeHref = "", backLabel = "xoffy", wordmarkHref = "", review = true,
                   reviewPage = "") =
  ## The page: both looks (Munari and the quaderno, `theme.nim`), the header with the switch and the
  ## masthead (the wordmark, then `section`, the part of the site the page belongs to, and
  ## `cadence`, how the page lives: kept up to date, one for every release, dated), and the footer. `homeHref` links back, with
  ## `backLabel` as its text (a devlog post links back to the devlog); `wordmarkHref` makes the
  ## wordmark a link (a post's wordmark links to the home page). Every page has the review mode
  ## (`review.nim`), its version line under the lede and **✎ Review**: `review = false` leaves it
  ## out, `reviewPage` keeps the key its comments are stored under when the file is renamed.
  let desc = if description.len > 0: "<meta name=\"description\" content=\"" & esc(description) & "\">\n" else: ""
  nb.doc.context["title"] = %(if title.len > 0: title else: "xoffy")
  nb.doc.context["stylesheet"] = %(desc &
    """<link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2280%22>✏️</text></svg>">""" &
    "\n" & temaHeadScript & "\n" & siteCss(nb.doc.filename, extra = reviewCss))
  nb.doc.context["highlight"] = %""
  nb.doc.context["nb_style"] = %""
  nb.doc.context["disableHighlightJs"] = %true
  for (key, value) in [("wordmark", "xoffy"), ("section", section), ("cadence", cadence), ("home_href", homeHref),
                       ("back_label", backLabel), ("wordmark_href", wordmarkHref)]:
    nb.doc.context[key] = %value
  nb.backend.partials["header"] = pageHeader
  nb.backend.partials["footer"] = pageFooter
  nb.backend.partials["nbText"] = pageText
  nb.backend.partials["left"] = emptyPartial
  nb.backend.partials["right"] = emptyPartial
  if review: nb.review(page = reviewPage, script = sharedReviewScript(nb), css = false)
