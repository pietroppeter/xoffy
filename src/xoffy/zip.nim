## The box: a zip archive, written and read.
##
## Every Office file (.pptx, .docx, .xlsx) is a zip of XML files. xoffy writes the zip itself,
## the classic format without ZIP64 (an Office file is far below its 4 GB), with the entries in
## the order given and a fixed date, so the same document gives the same bytes. Only deflate
## and inflate come from zippy.
##
## ```nim
## import xoffy/zip
## let z = writeZip([("hello.txt", "Hello, Office")])
## echo z[0 .. 3] == "PK\x03\x04", " ", readZip(z)["hello.txt"]
## ```

import std/[tables, strutils]
import zippy

type
  ZipError* = object of CatchableError
  ZipEntry* = tuple[name, data: string]

var crcTable: array[256, uint32]
for n in 0 ..< 256:
  var c = uint32(n)
  for k in 0 ..< 8:
    c = if (c and 1) != 0: 0xEDB88320'u32 xor (c shr 1) else: c shr 1
  crcTable[n] = c

proc crc32*(s: string): uint32 =
  ## The CRC-32 of `s`, the checksum zip keeps for every entry.
  result = 0xFFFFFFFF'u32
  for ch in s: result = crcTable[(result xor uint32(ord(ch))) and 0xFF] xor (result shr 8)
  result = result xor 0xFFFFFFFF'u32

proc le(s: var string, v: SomeInteger, n: int) =
  let v = uint64(v)
  for k in 0 ..< n: s.add chr(int((v shr (8 * k)) and 0xFF))

func get(s: string, pos, n: int): uint32 =
  if pos + n > s.len: raise newException(ZipError, "truncated zip")
  for k in countdown(n - 1, 0): result = (result shl 8) or uint32(ord(s[pos + k]))

const
  localSig = 0x04034b50'u32
  centralSig = 0x02014b50'u32
  endSig = 0x06054b50'u32
  dosDate = 0x21           # 1 January 1980, the first day zip can say
  utf8Flag = 0x0800        # names are UTF-8

proc writeZip*(entries: openArray[ZipEntry], deflate = true): string =
  ## The bytes of a zip with `entries`, in this order. With `deflate` (the default) an entry is
  ## compressed when that makes it smaller; otherwise it is stored as it is.
  var central = ""
  for (name, data) in entries:
    if name.len == 0 or name[0] == '/': raise newException(ZipError, "bad entry name: " & name)
    let offset = result.len
    let crc = crc32(data)
    var packed = data
    var meth = 0
    if deflate and data.len > 0:
      let c = compress(data, DefaultCompression, dfDeflate)
      if c.len < data.len: (packed, meth) = (c, 8)
    if offset > int(uint32.high) or packed.len > int(uint32.high):
      raise newException(ZipError, "too big for a zip without ZIP64")
    let flags = if name.allCharsInSet({'\0'..'\127'}): 0 else: utf8Flag
    result.le localSig, 4
    result.le 20, 2                       # version needed: 2.0
    result.le flags, 2
    result.le meth, 2
    result.le 0, 2                        # time
    result.le dosDate, 2
    result.le crc, 4
    result.le packed.len, 4
    result.le data.len, 4
    result.le name.len, 2
    result.le 0, 2                        # extra
    result.add name
    result.add packed
    central.le centralSig, 4
    central.le 20, 2                      # made by
    central.le 20, 2                      # needed
    central.le flags, 2
    central.le meth, 2
    central.le 0, 2
    central.le dosDate, 2
    central.le crc, 4
    central.le packed.len, 4
    central.le data.len, 4
    central.le name.len, 2
    central.le 0, 2                       # extra
    central.le 0, 2                       # comment
    central.le 0, 2                       # disk
    central.le 0, 2                       # internal attributes
    central.le 0, 4                       # external attributes
    central.le offset, 4
    central.add name
  let cdOffset = result.len
  result.add central
  result.le endSig, 4
  result.le 0, 2
  result.le 0, 2
  result.le entries.len, 2
  result.le entries.len, 2
  result.le central.len, 4
  result.le cdOffset, 4
  result.le 0, 2

proc readZip*(z: string): OrderedTable[string, string] =
  ## The entries of the zip `z`, name to content, in the order of its central directory.
  ## Stored and deflated entries are read; ZIP64 and encryption are not.
  var e = z.len - 22
  while e >= 0 and get(z, e, 4) != endSig: dec e
  if e < 0: raise newException(ZipError, "not a zip: no end of central directory")
  let count = int(get(z, e + 10, 2))
  var p = int(get(z, e + 16, 4))
  for _ in 0 ..< count:
    if get(z, p, 4) != centralSig: raise newException(ZipError, "bad central directory")
    let meth = get(z, p + 10, 2)
    let crc = get(z, p + 16, 4)
    let csize = int(get(z, p + 20, 4))
    let nlen = int(get(z, p + 28, 2))
    let xlen = int(get(z, p + 30, 2))
    let clen = int(get(z, p + 32, 2))
    let off = int(get(z, p + 42, 4))
    let name = z[p + 46 ..< p + 46 + nlen]
    p += 46 + nlen + xlen + clen
    if get(z, off, 4) != localSig: raise newException(ZipError, "bad local header: " & name)
    let start = off + 30 + int(get(z, off + 26, 2)) + int(get(z, off + 28, 2))
    if start + csize > z.len: raise newException(ZipError, "truncated entry: " & name)
    let packed = z[start ..< start + csize]
    let data = case meth
      of 0: packed
      of 8: uncompress(packed, dfDeflate)
      else: raise newException(ZipError, "unknown compression " & $meth & ": " & name)
    if crc32(data) != crc: raise newException(ZipError, "bad checksum: " & name)
    result[name] = data
