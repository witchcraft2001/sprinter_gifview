#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

if ! command -v zip >/dev/null 2>&1; then
  echo "Error: zip is not installed or not in PATH" >&2
  exit 1
fi

exe_path="$repo_root/build/GIFVIEW.EXE"
zip_path="$repo_root/distr/gifview.zip"

if [ ! -f "$exe_path" ]; then
  "$repo_root/tools/build.sh"
fi

mkdir -p "$repo_root/distr" "$repo_root/build/package"
rm -rf "$repo_root/build/package/gifview"
mkdir -p "$repo_root/build/package/gifview/demo"

cp "$exe_path" "$repo_root/build/package/gifview/GIFVIEW.EXE"
cp "$repo_root/readme.txt" "$repo_root/build/package/gifview/readme.txt"

for demo_name in 1.gif 2.gif 3.gif; do
  if [ -f "$repo_root/demo/$demo_name" ]; then
    cp "$repo_root/demo/$demo_name" "$repo_root/build/package/gifview/demo/$demo_name"
  else
    echo "Warning: demo/$demo_name not found, skipping" >&2
  fi
done

rm -f "$zip_path"
cd "$repo_root/build/package"
zip -qr "$zip_path" gifview

echo "Created $zip_path"
