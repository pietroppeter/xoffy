## The devlog's index, docs/devlog/index.html: every dated post, newest first, read from the first line of its source
## (`## devlog: <dd Mon yyyy> <letter> | <title> | <lede>`). Posts of the same day take a letter
## in the order they were written (07 Nov 2026 A, B, C, ...), so the newest is still first; the
## letter can be left out for a day with one post. A new post needs no entry here.
import std/[os, strutils, times, algorithm, strformat]
import nimib
import ../blocks

let here = currentSourcePath().parentDir

type Post = object
  slug, date, title, lede: string
  day: DateTime
  letter: string

var posts: seq[Post]
for kind, path in walkDir(here):
  let (_, name, ext) = path.splitFile
  if kind != pcFile or ext != ".nim" or name == "index": continue
  let first = readFile(path).splitLines[0]
  if not first.startsWith("## devlog:"): continue
  let parts = first["## devlog:".len .. ^1].split('|')
  if parts.len < 3: continue
  let stamp = parts[0].strip.splitWhitespace   # dd Mon yyyy, then maybe a letter
  posts.add Post(slug: name.replace('_', '-'), date: parts[0].strip, title: parts[1].strip,
                 lede: parts[2 .. ^1].join("|").strip, day: parse(stamp[0 .. 2].join(" "), "dd MMM yyyy"),
                 letter: (if stamp.len > 3: stamp[3] else: ""))
posts.sort(proc (a, b: Post): int = cmp((b.day, b.letter), (a.day, a.letter)))

nbInit
nb.doc.filename = here / "index.html"
nb.useXoffy(section = "Devlog", cadence = "dated posts",
            title = "xoffy devlog", homeHref = "../")

nbTitle "Devlog", "How xoffy is made", """
Dated posts on the steps that make xoffy, newest first. Each tells one step as it happened, and is
not rewritten afterwards (a typo or a link is fixed); the [home page](../) is kept up to date.
"""
nbCards "the posts, newest first":
  for p in posts:
    nbCard(p.title, p.slug & "/", p.date, nkPlain):
      nbText p.lede
nbSave
