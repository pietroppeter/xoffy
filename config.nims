# The library in src/; the dependencies are on the path from nim.cfg, which atlas writes.
import std/os
switch("path", thisDir() / "src")
switch("hints", "off")
