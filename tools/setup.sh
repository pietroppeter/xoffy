#!/bin/sh
# Gets a checkout ready to run the tests, the spec examples and the pages. It works on a laptop,
# in CI and in a fresh coding-agent sandbox (Claude Code on the web, Codex, ...), and is safe to
# rerun: each step is skipped when its tool is already there.
#
#   sh tools/setup.sh
#
# 1. Nim: when `nim` is not on the PATH, the GitHub nightly $NIM_NIGHTLY (default
#    latest-version-2-2) goes into $NIM_HOME (default ~/.local/nim). GitHub, not nim-lang.org,
#    because sandboxes often block nim-lang.org.
# 2. atlas: when `atlas` is missing or older than $ATLAS_MIN, the release $ATLAS_VERSION goes
#    into ~/.local/bin. (Nim ships atlas, but older Nim releases ship an atlas without features.)
# 3. libpcre3, which nimib's markdown loads at run time (Debian/Ubuntu, with apt).
# 4. the dependencies at the commits in atlas.lock: `atlas rep --feature=docs`, into deps/.
#    nim.cfg (committed, written by atlas) puts them on the path.
#
# The library needs Nim and zippy; nimib and tabelline are for the docs.
set -eu

NIM_NIGHTLY="${NIM_NIGHTLY:-latest-version-2-2}"
NIM_HOME="${NIM_HOME:-$HOME/.local/nim}"
ATLAS_VERSION="${ATLAS_VERSION:-0.16.4}"
ATLAS_MIN="${ATLAS_MIN:-0.16}"
here=$(cd "$(dirname "$0")/.." && pwd)
export PATH="$HOME/.local/bin:$NIM_HOME/bin:$PATH"
log() { echo "[setup] $*"; }

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) nimArchive=linux_x64.tar.xz;    atlasArchive=atlas-linux-amd64.tar.gz ;;
  Linux-aarch64) nimArchive=linux_arm64.tar.xz; atlasArchive=atlas-linux-arm64.tar.gz ;;
  Darwin-*) nimArchive=macosx_x64.tar.xz;       atlasArchive=atlas-macos-universal.tar.gz ;;
  *) nimArchive=""; atlasArchive="" ;;
esac
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# 1. Nim
if ! command -v nim >/dev/null 2>&1; then
  [ -n "$nimArchive" ] || { log "no Nim for $(uname -sm): install Nim 2.2 and rerun"; exit 1; }
  log "nim not found: downloading the $NIM_NIGHTLY nightly into $NIM_HOME"
  curl -sSfL --retry 6 --retry-delay 15 --retry-all-errors -o "$tmp/nim.tar.xz" \
    "https://github.com/nim-lang/nightlies/releases/download/$NIM_NIGHTLY/$nimArchive"
  tar -xf "$tmp/nim.tar.xz" -C "$tmp"
  rm -rf "$NIM_HOME" && mkdir -p "$(dirname "$NIM_HOME")"
  mv "$tmp"/nim-*/ "$NIM_HOME"
fi
log "$(nim -v | head -1)"

# 2. atlas
ATLAS=atlas
atlasVersion() { "$ATLAS" --version 2>/dev/null | sed -n 's/^version: \([0-9.]*\).*/\1/p'; }
older() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)" != "$2" ]; }
have=$(atlasVersion || true)
if [ -z "$have" ] || older "$have" "$ATLAS_MIN"; then
  [ -n "$atlasArchive" ] || { log "no atlas release for $(uname -sm): install atlas $ATLAS_MIN or later"; exit 1; }
  log "atlas ${have:-not found}: downloading atlas $ATLAS_VERSION into ~/.local/bin"
  curl -sSfL --retry 6 --retry-delay 15 --retry-all-errors -o "$tmp/atlas.tar.gz" \
    "https://github.com/nim-lang/atlas/releases/download/$ATLAS_VERSION/$atlasArchive"
  tar -xzf "$tmp/atlas.tar.gz" -C "$tmp"
  mkdir -p "$HOME/.local/bin"
  cp "$tmp"/atlas-*/atlas "$HOME/.local/bin/atlas"
  ATLAS="$HOME/.local/bin/atlas"
fi
log "atlas $(atlasVersion)"

# 3. libpcre3
if [ "$(uname -s)" = Linux ] && ! PATH="$PATH:/sbin:/usr/sbin" ldconfig -p 2>/dev/null | grep 'libpcre\.so\.[13]' >/dev/null; then
  log "libpcre not found: installing libpcre3"
  sudo=""; [ "$(id -u)" -ne 0 ] && sudo="sudo"
  if command -v apt-get >/dev/null 2>&1; then
    $sudo apt-get install -y -qq libpcre3 >/dev/null 2>&1 ||
      { $sudo apt-get update -qq && $sudo apt-get install -y -qq libpcre3 >/dev/null; } ||
      log "WARNING: could not install libpcre3; the pages need it"
  else
    log "WARNING: install PCRE (libpcre3 or pcre) with your package manager; the pages need it"
  fi
fi

# 4. dependencies
cd "$here"
log "dependencies from atlas.lock into deps/"
"$ATLAS" rep --feature=docs >"$tmp/atlas.log" 2>&1 || { cat "$tmp/atlas.log"; exit 1; }
git diff --quiet -- nim.cfg xoffy.nimble 2>/dev/null ||
  log "WARNING: atlas changed nim.cfg or xoffy.nimble (it restores them from atlas.lock): see git diff"
for d in deps/*/; do log "  $(basename "$d") $(git -C "$d" describe --tags --always 2>/dev/null)"; done

log "ready. If nim or atlas were installed now, put them on the PATH of your shell:"
log "  export PATH=\"\$HOME/.local/bin:$NIM_HOME/bin:\$PATH\""
