# Package

version       = "0.1.0"
author        = "Pietro Peterlongo"
description   = "Office files (PowerPoint first, then Word and Excel) from Nim"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 2.2.0"  # nimble 0.18+ (Nim 2.2) reads the `feature` block below
requires "zippy >= 0.10.16"  # deflate and inflate, the only thing the library does not do itself

# nimib for the pages, and tabelline for their tables: the `docs` feature, pinned in atlas.lock
# (`sh tools/setup.sh` replays it).
feature "docs":
  requires "nimib#head"  # nimib after 0.4.3, without the deprecated md (as tabelline)
  requires "https://github.com/pietroppeter/tabelline#head"  # 0.2 is on main, not yet tagged
