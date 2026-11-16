#!/usr/bin/env bash
# ゲームの決まった場面を撮る（tools/screenshots.gd）。画面の無いコンテナでは、仮想の画面（Xvfb）とソフトウェア描画で撮る。
# 手元（作業のセッションのコンテナ）で回すもの。CI には入れない。使い方は docs/screenshots.md。
#
#   tools/screenshots.sh <godot> <出力のディレクトリ> [場面,場面,…|all]
#   tools/screenshots.sh <godot> --list      場面の名前と説明の一覧（tools/screenshots.gd の SCENES から出す。撮らない）
set -euo pipefail

GODOT="${1:?godot のパスを指定する}"
if [ "${2:-}" = "--list" ]; then
  # SCENES の `"名前": "説明",` の行を、名前 + タブ + 説明で出す。
  awk '/^const SCENES := \{/ {on=1; next} on && /^\}/ {exit}
       on && match($0, /^\t"[^"]+": "/) {
         line=$0; sub(/^\t"/, "", line); name=line; sub(/".*/, "", name)
         desc=line; sub(/^[^"]+": "/, "", desc); sub(/",?$/, "", desc)
         print name "\t" desc }' "$(dirname "$0")/screenshots.gd"
  exit 0
fi
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
# スクリプトが読み込めない（文法の誤りなど）と、Godot は終わらずに待ち続ける。ログを見て、読み込めなかったら、すぐに止める。
timeout 600 "${cmd[@]}" >"$log" 2>&1 &
pid=$!
broken=""
while kill -0 "$pid" 2>/dev/null; do
  if grep -qE "Parse Error|Failed to load script" "$log"; then
    broken=1
    kill "$pid" 2>/dev/null || true
    break
  fi
  sleep 0.5
done
status=0
wait "$pid" || status=$?
if [ -n "$broken" ]; then
  echo "screenshots.sh: スクリプトが読み込めないので止めた。" >&2
  grep -E -A1 "Parse Error|Failed to load script" "$log" >&2
  exit 1
fi
grep -E "^screenshots:|SCRIPT ERROR|Parse Error" "$log" || true
if grep -q "^screenshots: 作れなかった場面:" "$log"; then
  echo "screenshots.sh: 作れなかった場面がある（ほかの場面は撮った）。場面の条件か、ルールの変わり方を確かめる。" >&2
  exit 1
fi
if [ "$status" != 0 ] || ! grep -qx "screenshots: OK" "$log"; then
  echo "screenshots.sh: 撮り終えられなかった（終了コード $status）。全体のログ:" >&2
  cat "$log" >&2
  exit 1
fi
