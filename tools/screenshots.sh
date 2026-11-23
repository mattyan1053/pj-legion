#!/usr/bin/env bash
# ゲームの決まった場面を撮る（tools/screenshots.gd）。画面の無いコンテナでは、仮想の画面（Xvfb）とソフトウェア描画で撮る。
# 手元（作業のセッションのコンテナ）で回すもの。CI には入れない。使い方は docs/screenshots.md。
# 打ち切りは 600 秒。全部を撮るときは SHOTS_TIMEOUT=<秒> で延ばす。
#
#   tools/screenshots.sh <godot> <出力のディレクトリ> [場面,場面,…|all] [--size=<幅>x<高さ>]
#                                        --size は窓の大きさ（既定は 1280x720）。
#                                        --unit-look=<組の名前> で駒の見た目の組を選ぶ（既定は game/unit_looks.gd の DEFAULT）。
#                                        --frame-time で、撮る前にその場面の 1 コマの時間を測って出す（前後の重さを比べる）。
#                                        --rendering-method=<forward_plus|gl_compatibility> で描画方式を選ぶ（既定は forward_plus。Windows の exe と同じ）。
#                                        --no-effects で、オプションの「画面の効果」を切って撮る（既定はオン）。
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
SHOTS="all"
SIZE="1280x720"
LOOK=()
METHOD=(--rendering-method forward_plus)
MEASURE=()
EFFECTS=()
for arg in "${@:3}"; do
  case "$arg" in
    --size=*) SIZE="${arg#--size=}" ;;
    --unit-look=*) LOOK=(--unit-look "${arg#--unit-look=}") ;;
    --frame-time) MEASURE=(--frame-time) ;;
    --no-effects) EFFECTS=(--no-effects) ;;
    --rendering-method=*) METHOD=(--rendering-method "${arg#--rendering-method=}") ;;
    *) SHOTS="$arg" ;;
  esac
done
if ! [[ "$SIZE" =~ ^[0-9]+x[0-9]+$ ]]; then
  echo "screenshots.sh: --size は <幅>x<高さ>（例: --size=1920x1080）" >&2
  exit 1
fi
cd "$(dirname "$0")/.."
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

# 取り込みが済んでいないと、素材が読めずに絵が欠ける。
timeout 120 "$GODOT" --headless --path . --import >/dev/null 2>&1 || true

cmd=("$GODOT" "${METHOD[@]}" --path . --resolution "$SIZE" -- --shots "$SHOTS" --out "$OUT" --size "$SIZE" "${LOOK[@]}" "${MEASURE[@]}" "${EFFECTS[@]}")
if [ -z "${DISPLAY:-}" ]; then
  cmd=(xvfb-run -a -s "-screen 0 ${SIZE}x24" "${cmd[@]}")
fi
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
# スクリプトが読み込めない（文法の誤りなど）と、Godot は終わらずに待ち続ける。ログを見て、読み込めなかったら、すぐに止める。
timeout ${SHOTS_TIMEOUT:-600} "${cmd[@]}" >"$log" 2>&1 &
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
# Forward+ を頼んだのに Vulkan が無いと、Godot は黙って互換の描画（OpenGL）に替えて撮る。見た目の基準と違う絵になるので、失敗にする。
if [ "${METHOD[1]}" = "forward_plus" ] && grep -q "switching to OpenGL" "$log"; then
  echo "screenshots.sh: Forward+ で撮れなかった（Vulkan が無く、互換の描画に替わった）。" >&2
  echo "  コンテナなら Vulkan のソフトウェア描画を入れる: apt-get install -y mesa-vulkan-drivers" >&2
  echo "  互換の描画で撮るなら --rendering-method=gl_compatibility を付ける。" >&2
  exit 1
fi
if grep -q "^screenshots: 作れなかった場面:" "$log"; then
  echo "screenshots.sh: 作れなかった場面がある（ほかの場面は撮った）。場面の条件か、ルールの変わり方を確かめる。" >&2
  exit 1
fi
if [ "$status" != 0 ] || ! grep -qx "screenshots: OK" "$log"; then
  echo "screenshots.sh: 撮り終えられなかった（終了コード $status）。全体のログ:" >&2
  cat "$log" >&2
  exit 1
fi
