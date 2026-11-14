#!/usr/bin/env bash
# プロジェクトを画面なしで取り込み、メインシーンを少しだけ動かして、
# スクリプトのエラーが出ないことを確かめる。CI と手元で同じものを使う。
#
#   tools/check.sh /path/to/godot
set -euo pipefail

GODOT="${1:-godot}"
cd "$(dirname "$0")/.."

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

"$GODOT" --headless --path . --import 2>&1 | tee "$log"
"$GODOT" --headless --path . --quit-after 60 2>&1 | tee -a "$log"

if grep -E "SCRIPT ERROR|Parse Error|^ERROR" "$log" >/dev/null; then
  echo "check: エラーが出ています" >&2
  exit 1
fi
echo "check: OK"
