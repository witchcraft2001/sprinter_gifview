#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

build_one() {
  name=$1
  src=$2
  out=$3
  ref=$4

  mkdir -p "$(dirname -- "$out")"
  sjasmplus --raw="$out" "$src" >/tmp/gifview_${name}_sjasmplus.log

  if cmp -s "$ref" "$out"; then
    echo "OK ${name} byte-perfect"
    return 0
  fi

  echo "FAIL ${name}: first differences:" >&2
  cmp -l "$ref" "$out" | sed -n '1,10p' >&2
  return 1
}

build_one \
  SGIVER \
  "$ROOT_DIR/references/sgiver/src/sgiver.asm" \
  "$ROOT_DIR/references/sgiver/build/SGIVER.EXE" \
  "$ROOT_DIR/references/sgiver/SGIVER.EXE"

build_one \
  FLICPLAY \
  "$ROOT_DIR/references/flicplay/src/flicplay.asm" \
  "$ROOT_DIR/references/flicplay/build/FLICPLAY.EXE" \
  "$ROOT_DIR/references/flicplay/FLICPLAY.EXE"
