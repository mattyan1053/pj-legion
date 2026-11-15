#!/usr/bin/env bash
# 試作の決まった場面を撮る（tools/screenshots.gd）。画面の無いコンテナでは、仮想の画面（Xvfb）とソフトウェア描画で撮る。
# 手元（作業のセッションのコンテナ）で回すもの。CI には入れない。使い方は docs/screenshots.md。
#
#   tools/screenshots.sh <godot> <出力のディレクトリ> [場面,場面,…|all]
set -euo pipefail

GODOT="${1:?godot のパスを指定する}"
OUT="${2:?出力のディレクトリを指定する}"
SHOTS="${3:-all}"
cd "$(dirname "$0")/.."
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

# 取り込みが済んでいないと、素材が読めずに絵が欠ける。
timeout 120 "$GODOT" --headless --path . --import >/dev/null 2>&1 || true

cmd=("$GODOT" --path . --resolution 1280x720 -- --shots "$SHOTS" --out "$OUT")
if [ -z "${DISPLAY:-}" ]; then
  cmd=(xvfb-run -a -s "-screen 0 1280x720x24" "${cmd[@]}")
fi
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
status=0
timeout 600 "${cmd[@]}" >"$log" 2>&1 || status=$?
grep -E "^screenshots:|SCRIPT ERROR|Parse Error" "$log" || true
if [ "$status" != 0 ] || ! grep -qx "screenshots: OK" "$log"; then
  echo "screenshots.sh: 撮り終えられなかった（終了コード $status）。全体のログ:" >&2
  cat "$log" >&2
  exit 1
fi
