import std/[unittest, tables, strutils, sequtils, xmlparser, xmltree]
import xoffy/[units, xml, zip, opc]

suite "units":
  test "every unit is a whole number of EMU":
    check int64(1.inch) == 914_400
    check int64(1.cm) == 360_000
    check int64(1.pt) == 12_700
    check int64(96.px) == int64(1.inch)
    check 72.pt == 1.inch
    check abs(2.54.cm.toInch - 1.0) < 1e-9
    check 1.inch / 2 == 0.5.inch

suite "xml":
  test "text is escaped and forbidden characters dropped":
    check esc("a < b & \"c\"") == "a &lt; b &amp; &quot;c&quot;"
    check esc("bell\a") == "bell"
  test "a tag with no body closes itself, empty attributes are left out":
    check tag("a:off", "", {"x": "0", "y": ""}) == "<a:off x=\"0\"/>"
    check tag("a:t", "hi") == "<a:t>hi</a:t>"

suite "zip":
  test "the checksum is the standard CRC-32":
    check crc32("The quick brown fox jumps over the lazy dog") == 0x414FA339'u32
  test "what is written is read back, in order":
    let big = "Office ".repeat(200)
    let z = writeZip([("b.txt", big), ("a/c.xml", "<c/>"), ("empty", ""), ("è.txt", "accent")])
    check z.startsWith("PK\x03\x04")
    check z.len < big.len            # deflated
    let r = readZip(z)
    check toSeq(r.keys) == @["b.txt", "a/c.xml", "empty", "è.txt"]
    check r["b.txt"] == big and r["empty"] == "" and r["è.txt"] == "accent"
  test "the same entries give the same bytes":
    check writeZip([("x", "1")]) == writeZip([("x", "1")])
  test "stored entries are read too":
    check readZip(writeZip([("x", "xxxxxxxxxxxxxxxx")], deflate = false))["x"] == "xxxxxxxxxxxxxxxx"

suite "package":
  test "relationships live beside their source":
    check relsName("") == "_rels/.rels"
    check relsName("ppt/slides/slide1.xml") == "ppt/slides/_rels/slide1.xml.rels"
  test "targets are relative to the source's folder, and resolve back":
    let t = "ppt/media/image1.png".relativeTo("ppt/slides/slide1.xml")
    check t == "../media/image1.png"
    check t.resolve("ppt/slides/slide1.xml") == "ppt/media/image1.png"
    check "ppt/presentation.xml".relativeTo("") == "ppt/presentation.xml"
  test "the same relationship twice has one id":
    var p = Package()
    check p.relate("a.xml", "b.xml", relImage) == "rId1"
    check p.relate("a.xml", "c.xml", relImage) == "rId2"
    check p.relate("a.xml", "b.xml", relImage) == "rId1"
    check p.relate("a.xml", "https://nim-lang.org", relHyperlink, external = true) == "rId3"
  test "content types: defaults by extension, overrides for the rest":
    var p = Package()
    p.add "x/main.xml", "application/vnd.test+xml", "<m/>"
    p.add "x/pic.png", "image/png", "PNG"
    let ct = parseXml(p.contentTypesXml)
    var defaults, overrides: seq[string]
    for n in ct:
      if n.tag == "Default": defaults.add n.attr("Extension")
      else: overrides.add n.attr("PartName")
    check "png" in defaults and "rels" in defaults
    check overrides == @["/x/main.xml"]
  test "a package is read back with its parts and relationships":
    var p = Package()
    p.add "x/main.xml", "application/vnd.test+xml", "<m/>"
    p.add "x/media/pic.png", "image/png", "PNG"
    discard p.relate("", "x/main.xml", relOfficeDocument)
    let id = p.relate("x/main.xml", "x/media/pic.png", relImage)
    let q = readPackage(p.toZip)
    check q.mainPart == "x/main.xml"
    check q.target("x/main.xml", id) == "x/media/pic.png"
    check q.parts.len == 2 and q["x/main.xml"] == "<m/>"
    check q.parts[q.find("x/main.xml")].contentType == "application/vnd.test+xml"
