#!/usr/bin/env bash
set -euo pipefail

if ! command -v mformat >/dev/null 2>&1 || ! command -v mcopy >/dev/null 2>&1 || ! command -v mmd >/dev/null 2>&1; then
  echo "Error: mtools is required (mformat, mcopy and mmd were not found)." >&2
  exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

exe_path="${1:-$repo_root/build/GIFVIEW.EXE}"
image_path="${2:-$repo_root/distr/gifview.img}"

if [ ! -f "$exe_path" ]; then
  "$repo_root/tools/build.sh"
fi

mkdir -p "$(dirname "$image_path")"
rm -f "$image_path"

mformat -C -i "$image_path" -f 1440 ::
mcopy -i "$image_path" -o "$exe_path" ::GIFVIEW.EXE
mcopy -i "$image_path" -o "$repo_root/readme.txt" ::README.TXT
mmd -i "$image_path" ::/DEMO

for demo_name in 1.gif 2.gif 3.gif; do
  if [ -f "$repo_root/demo/$demo_name" ]; then
    upper=$(printf '%s' "$demo_name" | tr 'a-z' 'A-Z')
    mcopy -i "$image_path" -o "$repo_root/demo/$demo_name" "::/DEMO/$upper"
  else
    echo "Warning: demo/$demo_name not found, skipping" >&2
  fi
done

echo "Created FAT12 image: $image_path"
