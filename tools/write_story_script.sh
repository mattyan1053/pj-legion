#!/usr/bin/env bash
# ストーリーの台本（docs/story-script/）を、話のファイル（game/story/）から書き直す（tools/write_story_script.gd）。
# 話のファイルを直したら回す。回し忘れると、テスト（tests/tools/test_story_script.gd）が落ちる。
#
#   tools/write_story_script.sh <godot>
set -euo pipefail
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
# 取り込みが済んでいないと、クラスの名前が引けない。
timeout 300 "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
# 出力は要る行だけに絞る。失敗（Godot が動かない、話のファイルの書き間違い）は、終了コードで呼んだ側へ返す。
out="$(mktemp)"
trap 'rm -f "$out"' EXIT
code=0
timeout 120 "$GODOT" --headless --path . -s res://tools/write_story_script.gd >"$out" 2>&1 || code=$?
grep -E "^story_script:|ERROR" "$out" || true
if [ "$code" != 0 ]; then
  echo "write_story_script: 失敗した（終了コード $code）" >&2
  exit "$code"
fi
