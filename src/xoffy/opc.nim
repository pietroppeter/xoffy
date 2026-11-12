## The package: parts, their content types, and the relationships between them.
##
## Inside the zip, an Office file is an *Open Packaging Conventions* package (ECMA-376 part 2):
##
## - **parts**: each file is a part, with a name (`ppt/slides/slide1.xml`) and a content type
##   (what kind of XML, or image, it is), listed in `[Content_Types].xml`;
## - **relationships**: a part finds the parts it uses (a slide its layout, its images) through
##   a file of relationships beside it (`ppt/slides/_rels/slide1.xml.rels`), each with an id
##   (`rId1`), a type and a target. The package's own relationships (`_rels/.rels`) name the
##   main part: the presentation, the document or the workbook.
##
## A `Package` holds the parts in order and the relationships of each, and `toZip` writes
## `[Content_Types].xml` and every `.rels` file from them. Every format of xoffy builds a
## Package; `readPackage` opens one again.
##
## ```nim
## import xoffy/opc
## var p = Package()
## p.add "hello.xml", "application/xml", "<hello/>"
## echo p.relate("", "hello.xml", relOfficeDocument)
## echo p.contentTypesXml
## ```

import std/[tables, strutils, xmlparser, xmltree, sequtils]
import xml, zip

const
  nsRelationships* = "http://schemas.openxmlformats.org/package/2006/relationships"
  nsContentTypes* = "http://schemas.openxmlformats.org/package/2006/content-types"
  relBase* = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/"
  relOfficeDocument* = relBase & "officeDocument"
  relCoreProperties* = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"
  relExtendedProperties* = relBase & "extended-properties"
  relTheme* = relBase & "theme"
  relImage* = relBase & "image"
  relHyperlink* = relBase & "hyperlink"
  ctRelationships* = "application/vnd.openxmlformats-package.relationships+xml"
  ctCoreProperties* = "application/vnd.openxmlformats-package.core-properties+xml"
  ctExtendedProperties* = "application/vnd.openxmlformats-officedocument.extended-properties+xml"
  ctTheme* = "application/vnd.openxmlformats-officedocument.theme+xml"

  defaultTypes* = {"rels": ctRelationships, "xml": "application/xml", "png": "image/png",
                   "jpeg": "image/jpeg", "jpg": "image/jpeg", "gif": "image/gif",
                   "svg": "image/svg+xml", "emf": "image/x-emf", "wmf": "image/x-wmf"}
    ## the content types a part gets from its extension, written as `Default` entries

type
  PackageError* = object of CatchableError
  Part* = object
    name*: string          ## its path in the zip, without a leading `/`: `ppt/slides/slide1.xml`
    contentType*: string
    data*: string
  Relationship* = object
    id*: string            ## `rId1`, unique among the relationships of one source
    kind*: string          ## the relationship type, a URI (`relImage`, ...)
    target*: string        ## the target as written: relative to the source's folder, or a URL
    external*: bool        ## a URL outside the package (a hyperlink)
  Package* = object
    parts*: seq[Part]
    rels*: OrderedTable[string, seq[Relationship]]
      ## the relationships of each source part; `""` is the package itself

func extOf(name: string): string =
  let dot = name.rfind('.')
  if dot < 0 or '/' in name[dot .. ^1]: "" else: name[dot + 1 .. ^1].toLowerAscii

func folderOf(name: string): string =
  let slash = name.rfind('/')
  if slash < 0: "" else: name[0 ..< slash]

func relsName*(source: string): string =
  ## Where the relationships of `source` live: `_rels/.rels` for the package (`""`),
  ## `ppt/slides/_rels/slide1.xml.rels` for `ppt/slides/slide1.xml`.
  if source.len == 0: "_rels/.rels"
  else:
    let f = folderOf(source)
    (if f.len > 0: f & "/" else: "") & "_rels/" & source[f.len + (if f.len > 0: 1 else: 0) .. ^1] & ".rels"

func relativeTo*(target, source: string): string =
  ## The name of `target` as a relationship of `source` writes it: relative to the folder of
  ## `source` (`../media/image1.png` from `ppt/slides/slide1.xml`).
  let a = folderOf(source).split('/').filterIt(it.len > 0)
  let b = target.split('/')
  var common = 0
  while common < a.len and common < b.len - 1 and a[common] == b[common]: inc common
  result = repeat("../", a.len - common) & b[common .. ^1].join("/")

func resolve*(target, source: string): string =
  ## The part a relationship of `source` points to: the reverse of `relativeTo`.
  if target.startsWith("/"): return target[1 .. ^1]
  var path = folderOf(source).split('/').filterIt(it.len > 0)
  for piece in target.split('/'):
    if piece == "..":
      if path.len > 0: discard path.pop
    elif piece notin ["", "."]: path.add piece
  path.join("/")

func find*(p: Package, name: string): int =
  ## The index of the part called `name`, or -1.
  for i, part in p.parts:
    if part.name == name: return i
  -1

func has*(p: Package, name: string): bool = p.find(name) >= 0

func `[]`*(p: Package, name: string): string =
  ## The content of the part `name`.
  let i = p.find(name)
  if i < 0: raise newException(PackageError, "no part " & name)
  p.parts[i].data

proc add*(p: var Package, name, contentType, data: string) =
  ## Adds a part, or replaces the content of the part with that name.
  let i = p.find(name)
  if i >= 0: p.parts[i] = Part(name: name, contentType: contentType, data: data)
  else: p.parts.add Part(name: name, contentType: contentType, data: data)

proc relate*(p: var Package, source, target, kind: string, external = false): string =
  ## Adds a relationship from the part `source` (`""` for the package) to the part `target`
  ## (its full name) or, when `external`, to the URL `target`, and returns its id. The same
  ## target and type twice give the same id.
  let written = if external: target else: target.relativeTo(source)
  var list = p.rels.getOrDefault(source)
  for r in list:
    if r.kind == kind and r.target == written and r.external == external: return r.id
  result = "rId" & $(list.len + 1)
  list.add Relationship(id: result, kind: kind, target: written, external: external)
  p.rels[source] = list

func relationsOf*(p: Package, source: string): seq[Relationship] = p.rels.getOrDefault(source)

func target*(p: Package, source, id: string): string =
  ## The full name of the part that the relationship `id` of `source` points to.
  for r in p.rels.getOrDefault(source):
    if r.id == id: return (if r.external: r.target else: r.target.resolve(source))
  raise newException(PackageError, "no relationship " & id & " in " & source)

func relsXml*(list: openArray[Relationship]): string =
  ## A `.rels` part.
  var body = ""
  for r in list:
    body.add tag("Relationship", "", {"Id": r.id, "Type": r.kind, "Target": r.target,
                                      "TargetMode": (if r.external: "External" else: "")})
  doc tag("Relationships", body, {"xmlns": nsRelationships})

func contentTypesXml*(p: Package): string =
  ## `[Content_Types].xml`: a `Default` for each extension in `defaultTypes` that a part uses
  ## with that type, and an `Override` for every other part.
  var used: seq[string] = @["rels"]
  for part in p.parts:
    let e = extOf(part.name)
    for (ext, ct) in defaultTypes:
      if ext == e and ct == part.contentType and e notin used: used.add e
  if "xml" notin used: used.add "xml"
  var body = ""
  for (ext, ct) in defaultTypes:
    if ext in used: body.add tag("Default", "", {"Extension": ext, "ContentType": ct})
  for part in p.parts:
    let e = extOf(part.name)
    var isDefault = false
    for (ext, ct) in defaultTypes:
      if ext == e and ct == part.contentType: isDefault = true
    if not isDefault:
      body.add tag("Override", "", {"PartName": "/" & part.name, "ContentType": part.contentType})
  doc tag("Types", body, {"xmlns": nsContentTypes})

proc toZip*(p: Package): string =
  ## The bytes of the package: `[Content_Types].xml` first, then the package's relationships,
  ## then each part followed by its relationships.
  var entries: seq[ZipEntry] = @[("[Content_Types].xml", p.contentTypesXml)]
  if p.rels.hasKey(""): entries.add ("_rels/.rels", relsXml(p.rels[""]))
  for part in p.parts:
    entries.add (part.name, part.data)
    if p.rels.hasKey(part.name) and p.rels[part.name].len > 0:
      entries.add (relsName(part.name), relsXml(p.rels[part.name]))
  writeZip(entries)

proc save*(p: Package, path: string) = writeFile(path, p.toZip)

proc readPackage*(bytes: string): Package =
  ## Opens the bytes of an Office file: its parts, with their content types, and its
  ## relationships.
  let files = readZip(bytes)
  if not files.hasKey("[Content_Types].xml"):
    raise newException(PackageError, "not an Office file: no [Content_Types].xml")
  var defaults = initTable[string, string]()
  var overrides = initTable[string, string]()
  for n in parseXml(files["[Content_Types].xml"]):
    if n.kind != xnElement: continue
    if n.tag == "Default": defaults[n.attr("Extension").toLowerAscii] = n.attr("ContentType")
    elif n.tag == "Override": overrides[n.attr("PartName").strip(chars = {'/'}, trailing = false)] = n.attr("ContentType")
  for name, data in files:
    if name == "[Content_Types].xml" or name.endsWith(".rels"): continue
    let ct = overrides.getOrDefault(name, defaults.getOrDefault(extOf(name)))
    result.parts.add Part(name: name, contentType: ct, data: data)
  for name, data in files:
    if not name.endsWith(".rels"): continue
    var source = name.replace("_rels/", "")
    source.removeSuffix(".rels")
    if name == "_rels/.rels": source = ""
    var list: seq[Relationship]
    for n in parseXml(data):
      if n.kind == xnElement and n.tag == "Relationship":
        list.add Relationship(id: n.attr("Id"), kind: n.attr("Type"), target: n.attr("Target"),
                              external: n.attr("TargetMode") == "External")
    result.rels[source] = list

proc openPackage*(path: string): Package = readPackage(readFile(path))

func mainPart*(p: Package): string =
  ## The name of the package's main part (the presentation, document or workbook).
  p.target("", p.relationsOf("").filterIt(it.kind == relOfficeDocument)[0].id)
