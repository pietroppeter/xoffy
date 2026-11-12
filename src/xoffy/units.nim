## Lengths, in the unit Office counts in.
##
## Office Open XML measures a slide, a shape or a line in EMU, *English Metric Units*: 914 400 to
## the inch and 360 000 to the centimetre, so that inches, centimetres and points are all whole
## numbers of it. xoffy keeps every length as an `Emu` and gives a constructor per unit:
##
## ```nim
## import xoffy/units
## echo 1.inch, " ", 2.5.cm, " ", 12.pt, " ", 96.px
## ```

import std/math

type Emu* = distinct int64
  ## A length in English Metric Units (1 inch = 914 400 EMU, 1 pt = 12 700 EMU).

const
  emuPerInch* = 914_400
  emuPerCm* = 360_000
  emuPerMm* = 36_000
  emuPerPt* = 12_700
  emuPerPx* = 9_525      ## a CSS pixel: 1/96 inch

func `==`*(a, b: Emu): bool {.borrow.}
func `<`*(a, b: Emu): bool {.borrow.}
func `<=`*(a, b: Emu): bool {.borrow.}
func `+`*(a, b: Emu): Emu {.borrow.}
func `-`*(a, b: Emu): Emu {.borrow.}
func `-`*(a: Emu): Emu {.borrow.}
func `+=`*(a: var Emu, b: Emu) {.borrow.}
func `-=`*(a: var Emu, b: Emu) {.borrow.}
func `*`*(a: Emu, k: SomeNumber): Emu = Emu(round(float(int64(a)) * float(k)).int64)
func `*`*(k: SomeNumber, a: Emu): Emu = a * k
func `/`*(a: Emu, k: SomeNumber): Emu = Emu(round(float(int64(a)) / float(k)).int64)
func `/`*(a, b: Emu): float = float(int64(a)) / float(int64(b))
func `$`*(a: Emu): string = $int64(a)
func max*(a, b: Emu): Emu = (if a < b: b else: a)
func min*(a, b: Emu): Emu = (if a < b: a else: b)

func toEmu(x: SomeNumber, per: int): Emu = Emu(round(float(x) * float(per)).int64)

func inch*(x: SomeNumber): Emu = toEmu(x, emuPerInch)  ## `1.inch`
func cm*(x: SomeNumber): Emu = toEmu(x, emuPerCm)      ## `2.5.cm`
func mm*(x: SomeNumber): Emu = toEmu(x, emuPerMm)      ## `5.mm`
func pt*(x: SomeNumber): Emu = toEmu(x, emuPerPt)      ## `12.pt`, a typographic point (1/72 inch)
func px*(x: SomeNumber): Emu = toEmu(x, emuPerPx)      ## `96.px`, a CSS pixel (1/96 inch)
func emu*(x: SomeInteger): Emu = Emu(int64(x))          ## `914400.emu`

func toPt*(a: Emu): float = float(int64(a)) / float(emuPerPt)    ## the length in points
func toInch*(a: Emu): float = float(int64(a)) / float(emuPerInch)
func toCm*(a: Emu): float = float(int64(a)) / float(emuPerCm)
func toPx*(a: Emu): float = float(int64(a)) / float(emuPerPx)

func sum*(xs: openArray[Emu]): Emu =
  for x in xs: result += x
