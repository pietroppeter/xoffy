## Pictures: what kind they are and how many pixels they have.
##
## A picture goes into the package as it is (a part in `ppt/media/`). To place it, xoffy needs
## its format (for the content type) and its size in pixels (for its shape, when only a width
## or a height is given): both are in the first bytes of a PNG, a JPEG or a GIF.
##
## ```nim
## import xoffy/images
## let png = solidPng(4, 3, (225, 107, 140))
## echo png.imageInfo
## ```

import zippy
import zip

type
  ImageInfo* = object
    ext*: string           ## `png`, `jpeg`, `gif`
    contentType*: string
    width*, height*: int   ## in pixels
  ImageError* = object of CatchableError

func be(s: string, pos, n: int): int =
  for k in 0 ..< n: result = (result shl 8) or ord(s[pos + k])

func imageInfo*(data: string): ImageInfo =
  ## The format and pixel size of a PNG, JPEG or GIF.
  if data.len >= 24 and data[0 .. 7] == "\x89PNG\r\n\x1a\n":
    return ImageInfo(ext: "png", contentType: "image/png", width: be(data, 16, 4), height: be(data, 20, 4))
  if data.len >= 10 and data[0 .. 2] == "GIF":
    return ImageInfo(ext: "gif", contentType: "image/gif",
                     width: ord(data[6]) or (ord(data[7]) shl 8), height: ord(data[8]) or (ord(data[9]) shl 8))
  if data.len >= 4 and data[0] == '\xFF' and data[1] == '\xD8':
    var p = 2
    while p + 9 < data.len:
      if data[p] != '\xFF': inc p; continue
      let marker = ord(data[p + 1])
      if marker in [0xD8, 0x01] or marker in 0xD0..0xD7: p += 2; continue
      let len = be(data, p + 2, 2)
      if marker in 0xC0..0xCF and marker notin [0xC4, 0xC8, 0xCC]:
        return ImageInfo(ext: "jpeg", contentType: "image/jpeg", width: be(data, p + 7, 2), height: be(data, p + 5, 2))
      p += 2 + len
  raise newException(ImageError, "not a PNG, JPEG or GIF")

proc chunk(kind, data: string): string =
  for k in countdown(3, 0): result.add chr((data.len shr (8 * k)) and 0xFF)
  result.add kind & data
  let c = crc32(kind & data)
  for k in countdown(3, 0): result.add chr(int((c shr (8 * k)) and 0xFF))

proc png*(width, height: int, pixel: proc (x, y: int): (int, int, int)): string =
  ## A PNG of `width` × `height` pixels, each coloured by `pixel(x, y)` (red, green, blue, 0..255):
  ## enough to make a picture in a test or an example without a file.
  var raw = newStringOfCap((width * 3 + 1) * height)
  for y in 0 ..< height:
    raw.add '\0'
    for x in 0 ..< width:
      let (r, g, b) = pixel(x, y)
      raw.add chr(clamp(r, 0, 255)); raw.add chr(clamp(g, 0, 255)); raw.add chr(clamp(b, 0, 255))
  var ihdr = ""
  for v in [width, height]:
    for k in countdown(3, 0): ihdr.add chr((v shr (8 * k)) and 0xFF)
  ihdr.add "\x08\x02\x00\x00\x00"   # 8 bits, RGB, deflate, no filter, no interlace
  "\x89PNG\r\n\x1a\n" & chunk("IHDR", ihdr) & chunk("IDAT", compress(raw, DefaultCompression, dfZlib)) & chunk("IEND", "")

proc solidPng*(width, height: int, color: (int, int, int)): string =
  png(width, height, proc (x, y: int): (int, int, int) = color)
