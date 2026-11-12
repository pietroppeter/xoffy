import std/[unittest, strutils, xmlparser, xmltree]
import xoffy, xoffy/opc

proc helloDeck(): Presentation =
  result = newPresentation(title = "Hello")
  var s = slide(textBox("Hello, Office", box(1.inch, 1.inch, 8.inch, 1.inch), Font(size: 40)))
  s.add shape(gEllipse, box(1.inch, 3.inch, 2.inch, 2.inch), rgb"E16B8C")
  s.add connector(4.inch, 4.inch, 3.inch, 3.inch, line(rgb"000000", tail = ahTriangle))
  s.add picture(solidPng(40, 20, (0, 137, 167)), 5.inch, 3.inch, w = 2.inch)
  s.add tableFrame(newGrid(@[@["a", "b"]]), 8.inch, 3.inch)
  var t = textBox(markdown"[nim](https://nim-lang.org)", box(1.inch, 6.inch, 3.inch, 1.inch))
  s.add t
  result.add s
  result.add slide(background = rgb"FCFAF2")

suite "pictures":
  test "the size of a PNG, a GIF and a JPEG":
    let i = imageInfo(solidPng(40, 20, (1, 2, 3)))
    check i.ext == "png" and i.width == 40 and i.height == 20
    check imageInfo("GIF89a\x10\x00\x08\x00").width == 16
    let jpeg = "\xFF\xD8\xFF\xE0\x00\x04ab\xFF\xC0\x00\x11\x08\x00\x30\x00\x40\x03"
    let j = imageInfo(jpeg)
    check j.ext == "jpeg" and j.width == 64 and j.height == 48
  test "one side given, the other keeps the proportions":
    let p = picture(solidPng(40, 20, (1, 2, 3)), 0.inch, 0.inch, w = 2.inch)
    check p.box.h == 1.inch

suite "presentation":
  let pkg = readPackage(helloDeck().toPptx)
  test "the package has the parts PowerPoint expects":
    for part in ["ppt/presentation.xml", "ppt/slides/slide1.xml", "ppt/slides/slide2.xml",
                 "ppt/slideMasters/slideMaster1.xml", "ppt/slideLayouts/slideLayout1.xml",
                 "ppt/theme/theme1.xml", "ppt/media/image1.png", "docProps/core.xml", "docProps/app.xml"]:
      check pkg.has(part)
    check pkg.mainPart == "ppt/presentation.xml"
  test "every XML part is well formed":
    for part in pkg.parts:
      if part.name.endsWith(".xml"):
        discard parseXml(part.data)
  test "the presentation lists its slides, the slides find their layout":
    let pres = parseXml(pkg["ppt/presentation.xml"])
    check pres.child("p:sldIdLst").len == 2
    for r in pkg.relationsOf("ppt/slides/slide1.xml"):
      if r.kind == relBase & "slideLayout": check r.target == "../slideLayouts/slideLayout1.xml"
  test "a slide holds a shape of each kind":
    let s = pkg["ppt/slides/slide1.xml"]
    check s.count("<p:sp>") == 3 and "<p:cxnSp>" in s and "<p:pic>" in s and "<p:graphicFrame>" in s
    check "flipH=\"1\" flipV=\"1\"" in s
  test "a link is an external relationship of its slide":
    var found = false
    for r in pkg.relationsOf("ppt/slides/slide1.xml"):
      if r.kind == relHyperlink and r.external and r.target == "https://nim-lang.org": found = true
    check found
  test "a picture used twice is stored once":
    var p = newPresentation()
    let png = solidPng(4, 4, (0, 0, 0))
    p.add slide(picture(png, 0.inch, 0.inch), picture(png, 1.inch, 0.inch))
    p.add slide(picture(png, 0.inch, 0.inch))
    let q = readPackage(p.toPptx)
    check q.has("ppt/media/image1.png") and not q.has("ppt/media/image2.png")
  test "a background, and the slide size":
    check "<p:bg><p:bgPr><a:solidFill><a:srgbClr val=\"FCFAF2\"/>" in pkg["ppt/slides/slide2.xml"]
    check "<p:sldSz cx=\"12192000\" cy=\"6858000\"/>" in pkg["ppt/presentation.xml"]
  test "the same deck gives the same bytes":
    check helloDeck().toPptx == helloDeck().toPptx
