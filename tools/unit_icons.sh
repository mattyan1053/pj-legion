#!/usr/bin/env bash
# 駒のアイコン（assets/unit_icons/）を、駒の 3D の形から写して書き直す（tools/unit_icons.gd）。
# 駒の形（game/looks/ の組の定義）や陣営の色を変えたら回す。手元（作業のセッションのコンテナ）で回し、CI には入れない。
#
#   tools/unit_icons.sh <godot> [組の名前]   組の名前（game/unit_looks.gd の SETS）を省くと、全部の組を書く
set -euo pipefail
GODOT="${1:-godot}"
LOOK="${2:-}"
cd "$(dirname "$0")/.."
# 取り込みが済んでいないと、素材が読めずに絵が欠ける。
timeout 120 "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
cmd=("$GODOT" --path . --resolution 256x256 -s res://tools/unit_icons.gd)
if [ -n "$LOOK" ]; then
  cmd+=(-- --look "$LOOK")
fi
if [ -z "${DISPLAY:-}" ]; then
  cmd=(xvfb-run -a -s "-screen 0 640x480x24" "${cmd[@]}")
fi
timeout 300 "${cmd[@]}" 2>&1 | grep -E "^unit_icons:|ERROR" || true
# 書いた PNG を取り込む（.import を作る）。
timeout 120 "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
find assets/unit_icons -name '*.png' | wc -l
