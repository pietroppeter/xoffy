## Writing XML, the small way.
##
## Every part of an Office file is an XML document. xoffy writes them as strings, with three
## helpers: `esc` for text and attribute values, `tag` for an element and `attrs` for its
## attributes. Nothing is indented: whitespace inside `<a:t>` is text, so the output is written
## as Office itself writes it, on one line.
##
## ```nim
## import xoffy/xml
## echo tag("a:t", esc("1 < 2 & 3"))
## echo tag("a:off", "", {"x": "0", "y": "0"})
## ```

const xmlHead* = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
  ## the declaration every part begins with

func esc*(s: string): string =
  ## `s` as XML text or attribute value: `& < > "` escaped, and the control characters XML 1.0
  ## forbids (all below space but tab, newline and return) dropped.
  result = newStringOfCap(s.len)
  for c in s:
    case c
    of '&': result.add "&amp;"
    of '<': result.add "&lt;"
    of '>': result.add "&gt;"
    of '"': result.add "&quot;"
    of '\t', '\n', '\r': result.add c
    of '\0'..'\8', '\11', '\12', '\14'..'\31': discard
    else: result.add c

func attrs*(pairs: openArray[(string, string)]): string =
  ## ` k="v"` for every pair whose value is not empty, the value escaped.
  for (k, v) in pairs:
    if v.len > 0: result.add " " & k & "=\"" & esc(v) & "\""

func tag*(name: string, body = "", pairs: openArray[(string, string)] = []): string =
  ## `<name k="v">body</name>`, or `<name k="v"/>` when the body is empty. The body is XML
  ## already: escape text with `esc`.
  if body.len == 0: "<" & name & attrs(pairs) & "/>"
  else: "<" & name & attrs(pairs) & ">" & body & "</" & name & ">"

func doc*(root: string): string = xmlHead & root
  ## a whole part: the declaration, then the root element

func onOff*(b: bool): string = (if b: "1" else: "0")
