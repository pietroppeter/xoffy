## xoffy: Office files from Nim.
##
## `import xoffy` gives everything needed to write a PowerPoint presentation: lengths
## (`xoffy/units`), DrawingML's colours, text and tables (`xoffy/drawingml`), pictures
## (`xoffy/images`) and the presentation itself (`xoffy/pptx`). The box and the package under
## them (`xoffy/zip`, `xoffy/opc`) are imported on their own, for reading or for a format xoffy
## does not write yet.
##
## ```nim
## import xoffy
## var deck = newPresentation()
## deck.add slide(textBox("Hello, Office", box(1.inch, 1.inch, 8.inch, 1.inch), Font(size: 40)))
## deck.save "hello.pptx"
## ```

import xoffy/[units, drawingml, images, pptx]
export units, drawingml, images, pptx

const xoffyVersion* = "0.1.0"
