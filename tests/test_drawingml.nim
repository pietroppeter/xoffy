import std/[unittest, strutils, xmlparser]
import xoffy

proc wellFormed(s: string): bool =
  try:
    discard parseXml("<root xmlns:a=\"a\" xmlns:r=\"r\" xmlns:p=\"p\">" & s & "</root>")
    true
  except CatchableError: false

suite "colours and lines":
  test "a colour from hex, from numbers, from the theme":
    check rgb"#e16b8c".hex == "E16B8C"
    check rgb"abc".hex == "AABBCC"
    check rgb(225, 107, 140) == rgb"E16B8C"
    check colorXml(scheme(accent2)) == "<a:schemeClr val=\"accent2\"/>"
    check colorXml(rgb"000000".withAlpha(0.25)) == "<a:srgbClr val=\"000000\"><a:alpha val=\"25000\"/></a:srgbClr>"
  test "inherit writes nothing, none writes noFill":
    check fillXml(inherit) == ""
    check fillXml(noColor) == "<a:noFill/>"
  test "a line with an arrow":
    let x = lineXml(line(rgb"1C1C1C", 2.pt, dsDash, tail = ahTriangle))
    check x.startsWith("<a:ln w=\"25400\">")
    check "<a:prstDash val=\"dash\"/>" in x and "<a:tailEnd type=\"triangle\"/>" in x

suite "text":
  test "a run with its font":
    let x = run("Hello", Font(size: 20, bold: true, color: rgb"E16B8C", typeface: "Jost")).runXml
    check x == "<a:r><a:rPr lang=\"en-US\" sz=\"2000\" b=\"1\"><a:solidFill><a:srgbClr val=\"E16B8C\"/></a:solidFill>" &
      "<a:latin typeface=\"Jost\"/><a:cs typeface=\"Jost\"/></a:rPr><a:t>Hello</a:t></a:r>"
  test "a newline in a run is a line break":
    check "<a:br>" in run("one\ntwo").runXml
  test "inline Markdown becomes runs":
    let rs = inline("plain **bold** *it* `code` x^2^ H~2~O [link](https://x.org)")
    var seen: seq[string]
    for r in rs:
      if r.font.bold: seen.add "b:" & r.text
      if r.font.italic: seen.add "i:" & r.text
      if r.font.typeface == "Menlo": seen.add "c:" & r.text
      if r.font.baseline == 30: seen.add "sup:" & r.text
      if r.font.baseline == -25: seen.add "sub:" & r.text
      if r.link.len > 0: seen.add "a:" & r.text & ">" & r.link
    check seen == @["b:bold", "i:it", "c:code", "sup:2", "sub:2", "a:link>https://x.org"]
  test "snake_case words stay words":
    check inline("a_b_c").len == 1
  test "lines of Markdown become paragraphs, with bullets and numbers":
    let f = md("Title\n- one\n  - nested\n1. first")
    check f.paragraphs.len == 4
    check f.paragraphs[1].bullet.kind == bkChar
    check f.paragraphs[2].level == 1
    check f.paragraphs[3].bullet.kind == bkNumber
    check f.plainText == "Title\none\nnested\nfirst"
  test "a paragraph's XML is well formed":
    check wellFormed(paragraphsXml(md("**a** & <b>\n- c")))

suite "grids (tables)":
  test "a grid of text":
    let g = newGrid(@[@["a", "b"], @["c", "d"]], colWidth = 2.inch)
    check g.cols.len == 2 and g.rows.len == 2
    check g.width == 4.inch
    check g[1, 1].text.plainText == "d"
  test "merged cells span, the covered ones are marked":
    var g = newGrid(3, 3)
    g.merge(0, 0, 1, 1)
    let x = tableXml(g)
    check "gridSpan=\"2\" rowSpan=\"2\"" in x
    check x.count("hMerge=\"1\"") == 2 and x.count("vMerge=\"1\"") == 2
    check wellFormed(x)
  test "a grid with no style says what it does not draw":
    var g = newGrid(1, 1)
    g[0, 0].borders[sdBottom] = line(rgb"000000")
    let x = tableXml(g)
    check "<a:lnL w=\"0\"><a:noFill/></a:lnL>" in x
    check "<a:lnB w=\"12700\" cmpd=\"sng\">" in x
