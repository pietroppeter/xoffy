# Changelog

## Unreleased

- Tables: two cells side by side get the same line on the edge they share, the stronger of the
  two (`collapseBorders`, done by `tableXml`). PowerPoint keeps only the top or left cell's line,
  so a rule set on the other side (a line between rows, on the lower row) was lost.

## 0.1.0 (to be released)

- A PowerPoint writer: a zip and an OPC package of its own (deterministic bytes), DrawingML
  colours, lines, text with Markdown, 48 preset shapes, connectors, pictures (PNG, GIF, JPEG)
  and native tables with merges and borders; blank 16:9 or 4:3 slides with a theme.
- The pages: home and four devlog posts.
