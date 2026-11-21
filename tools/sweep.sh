#!/usr/bin/env bash
# 通しの点検の長い道（game/autoplay_sweeps.gd）を回す。PR ごとの検査（tools/check.sh）には入れない。長い検査（--full）が同じものを回す。
#
#   tools/sweep.sh <godot> [story|versus|all]   # 既定は all
#
# story: 両方の物語を第 1〜15 話まで画面の道で通す（会話を送る、途中の台詞を送る、わざと負けて負けの台詞を見る）。
# versus: 対戦モードの全部のマップを、試しの決まりを全部切ったものと全部入れたもので、数ターン進める。
# エラーが出るか、"autoplay: OK" が出なければ失敗にする。ログは標準出力へ。
set -u
GODOT="${1:?godot のパスを渡す}"
what="${2:-all}"
cd "$(dirname "$0")/.."
case "$what" in
  story) args=(--story-all) ;;
  versus) args=(--versus-all) ;;
  all) args=(--story-all --versus-all) ;;
  *) echo "sweep: story / versus / all のどれか" >&2; exit 2 ;;
esac
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
"$GODOT" --headless --path . --import >/dev/null 2>&1
timeout "${RUN_TIMEOUT:-600}" "$GODOT" --headless --path . --fixed-fps 60 -- --autoplay "${args[@]}" >"$log" 2>&1
code=$?
cat "$log"
if [ "$code" != 0 ] || grep -E "SCRIPT ERROR|Parse Error|^ERROR|handle_crash" "$log" >/dev/null || ! grep -Fx "autoplay: OK" "$log" >/dev/null; then
  echo "sweep: 失敗（終わりの値 $code）" >&2
  exit 1
fi
echo "sweep: OK"
