# Backlog

Ideas, in the order of the [roadmap](https://pietroppeter.github.io/xoffy/devlog/roadmap/).
When one ships, remove it here and add a line to CHANGELOG.md.

## Before 0.2
- Open every deck of the pages in PowerPoint (and Keynote, Google Slides); record what each says.
- A validator in CI (the ECMA-376 schemas), so every deck the tests and pages write is checked.
- Specs: adopt OpenSpec as tabelline and diagrammari do.

## 0.2: decks you already have
- Open a deck and write it back, keeping every part xoffy does not understand.
- Layouts and placeholders of a template; a slide from a layout, placeholders filled by name.
- Speaker notes; groups; SVG pictures with a PNG fallback; gradients; custom geometry.
- Connectors glued to shapes (for diagrammari).

## 0.3: Excel workbooks
- Sheets, cells (shared strings, numbers, booleans, dates), formulas as text.
- Number formats and styles; merged cells, column widths, frozen panes, filters.
- Reading values. Read the Nim libraries next door first (excelin, xl, xlsx, opendocs).
- tabelline/xlsx; nanuq data frames to and from a sheet.

## 0.4: Word documents
- Paragraphs, runs, styles, lists, `w:tbl` tables (a second writer for `Grid`), pictures, sections.
- A template's styles; a nimib page as a .docx.

## 0.5: charts
- DrawingML charts with an embedded workbook: bars, lines, points, areas, pies.

## Later
- OpenDocument (odp, ods, odt); text extraction; Office's clipboard formats; embedded fonts.
