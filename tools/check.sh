#!/usr/bin/env bash
# リポジトリの置き方を確かめ、プロジェクトを画面なしで取り込み、テスト（tests/）を実行し、
# メインシーンで自動の対戦（game/autoplay.gd）を最後まで進めて、スクリプトのエラーが出ないことを確かめる。
# CI と手元で同じものを使う。テストと自動の対戦は、取り込みのあと並べて回す。
# 終わりに、まとまりごとに掛かった秒数を出す。
#
#   tools/check.sh /path/to/godot          PR ごとの検査（CI の check）
#   tools/check.sh --full /path/to/godot   長い検査（時間の掛かるテストと、自動の対戦のほかのマップ、
#                                          スクリーンショットの場面のいくつかを撮らずに作ること、も回す）
set -euo pipefail

full=""
if [ "${1:-}" = "--full" ]; then
  full="--full"
  shift
fi
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."

# --- Godot を使わない検査 ---
problems=0
problem() {
  echo "check: $1" >&2
  problems=1
}

# スクリプトの .uid は Godot が作る。コミットし忘れると、別の環境で参照が切れる。
while IFS= read -r script; do
  git ls-files --error-unmatch "$script.uid" >/dev/null 2>&1 || problem "$script.uid がコミットされていない"
done < <(git ls-files '*.gd')

# 素材は、置いたディレクトリか、その親（assets/ より下）に LICENSE* を持つ。
while IFS= read -r file; do
  dir="$(dirname "$file")"
  found=0
  while [ "$dir" != "assets" ] && [ "$dir" != "." ]; do
    if compgen -G "$dir/LICENSE*" >/dev/null; then
      found=1
      break
    fi
    dir="$(dirname "$dir")"
  done
  [ "$found" = 1 ] || problem "$file にライセンスの表記（LICENSE*）が無い"
done < <(git ls-files 'assets/**' | grep -vE '\.import$|/(LICENSE[^/]*|README\.md)$')

[ "$problems" = 0 ] || exit 1

# --- Godot を使う検査 ---
logs="$(mktemp -d)"
trap 'rm -rf "$logs"' EXIT

# スクリプトが読み込めないと Godot は終わらずに待ち続けることがあるので、時間で打ち切る（秒）。
# 長い検査は、いちばん長いまとまりが手元・CI で 1 分ほど。ジョブの上限（full-check の 10 分）の中で、余裕を持たせる。
if [ -n "$full" ]; then
  RUN_TIMEOUT="${RUN_TIMEOUT:-300}"
else
  RUN_TIMEOUT="${RUN_TIMEOUT:-120}"
fi
# 掛かった秒数を $logs/<名前>.time に書く。打ち切られたら、そう書く（終了コード 124）。
run() {
  local name="$1"
  shift
  local started=$SECONDS code=0
  timeout "$RUN_TIMEOUT" "$GODOT" --headless --path . "$@" >"$logs/$name.log" 2>&1 || code=$?
  if [ "$code" = 124 ]; then
    echo "$name: $((SECONDS - started)) 秒（${RUN_TIMEOUT} 秒で打ち切り）" >"$logs/$name.time"
  else
    echo "$name: $((SECONDS - started)) 秒" >"$logs/$name.time"
  fi
  return "$code"
}
# 並べて回すまとまり。名前を names に、プロセスを pids に積む（ログは混ぜずに、終わってから順に出す）。
names=()
pids=()
start() {
  local name="$1"
  run "$@" &
  names+=("$name")
  pids+=($!)
}
# 長い検査で、撮らずに作るスクリーンショットの場面（tools/screenshots.gd）。ルールや数値が変わると作れなくなりやすいもの。
# 全部を作ると 5 分ほど掛かるので、いくつかに絞る（全部は、撮る人が tools/screenshots.sh で確かめる）。
# 2 つのまとまりに分けて並べて回す（どちらも 30 秒ほど）。story_open_all は story_cleared の前に置き、前の場面の状態が残らないことも見る。
SHOTS_IN_FULL_A="mid_boss,forecast_skill,forecast_defeat,phase_camera,story_open_all,story_cleared"
SHOTS_IN_FULL_B="skill_fireball,skill_shadow,ult_eruption,result"

started=$SECONDS
run import --import || { cat "$logs/import.log"; exit 1; }
cat "$logs/import.log"
# テストと自動の対戦は互いに関わらないので、並べて回す。
# `test_long_` でないテストは 2 つのまとまりに分ける（1 つだと、CI でいちばん長いまとまりになる）。
# TESTS_APART に挙げたファイル（時間の掛かるもの）を別に回し、残りを全部 tests で回す（足したテストが漏れない）。
TESTS_APART="test_hand_map.gd,test_battle_log.gd,test_horde.gd,test_board_generator.gd,test_monsters.gd,test_stronghold.gd"
start tests -s res://tools/run_tests.gd -- --except="$TESTS_APART"
start tests_apart -s res://tools/run_tests.gd -- --only="$TESTS_APART"
# 自動の対戦。画面の描画を待たずに進める（--fixed-fps）。終わらなければ、コマ数で打ち切る。
# 場面を 2 つのまとまり（イベントを再生する場面と、操作の決まりの場面。game/autoplay.gd の GROUPS）に分けて、並べて回す。
start autoplay --fixed-fps 60 --quit-after 20000 -- --autoplay --only events $full
start autoplay_ui --fixed-fps 60 --quit-after 20000 -- --autoplay --only ui
# 操作の決まりの場面は、横長の画面（3440x1440 の窓。docs/screen-size.md）でも回す（部品が重ならない・はみ出さないこと）。
start autoplay_ui_wide --fixed-fps 60 --quit-after 20000 -- --autoplay --only ui --size 3440x1440
if [ -n "$full" ]; then
  # 長いテスト（`test_long_`）は 3 つのまとまりに分ける。全マップで CPU どうしが最後まで進むテストは、
  # 軍の並びごとに 1 つずつ（マップが増えると、この 2 つが伸びる）。残りは、ほかの長いテスト全部。
  start tests_long_maps_military -s res://tools/run_tests.gd -- --long-only --only=on_every_map_finish_military_first
  start tests_long_maps_fantasy -s res://tools/run_tests.gd -- --long-only --only=on_every_map_finish_fantasy_first
  start tests_long_rest -s res://tools/run_tests.gd -- --long-only --except=on_every_map_finish_
  # 通しの点検の長い道（game/autoplay_sweeps.gd。tools/sweep.sh と同じもの）。話を全部と、対戦モードの全部のマップ × 選べる決まりの入・切。
  start sweep_story --fixed-fps 60 -- --autoplay --story-all
  start sweep_versus --fixed-fps 60 -- --autoplay --versus-all
  start shots_a -- --shots "$SHOTS_IN_FULL_A" --dry-run
  start shots_b -- --shots "$SHOTS_IN_FULL_B" --dry-run
fi
status=0
for i in "${!pids[@]}"; do
  wait "${pids[$i]}" || { status=1; echo "check: ${names[$i]} が失敗した" >&2; }
done
for name in "${names[@]}"; do
  cat "$logs/$name.log"
done
# どのまとまりに何秒掛かったか（次に伸びたとき、どこが伸びたか分かるように）。
echo "check: 掛かった時間（全体 $((SECONDS - started)) 秒）"
for name in import "${names[@]}"; do
  echo "  $(cat "$logs/$name.time")"
done
[ "$status" = 0 ] || { echo "check: テストか自動の対戦（か、スクリーンショットの場面）が失敗した" >&2; exit 1; }

if cat "$logs"/*.log | grep -E "SCRIPT ERROR|Parse Error|^ERROR" >/dev/null; then
  echo "check: エラーが出ています" >&2
  exit 1
fi
for name in autoplay autoplay_ui autoplay_ui_wide; do
  if ! grep -F "autoplay: OK" "$logs/$name.log" >/dev/null; then
    echo "check: 自動の対戦が最後まで進まなかった（$name）" >&2
    exit 1
  fi
done
if [ -n "$full" ]; then
  for name in sweep_story sweep_versus; do
    if ! grep -Fx "autoplay: OK" "$logs/$name.log" >/dev/null; then
      echo "check: 通しの点検の長い道が最後まで進まなかった（$name）" >&2
      exit 1
    fi
  done
  for name in shots_a shots_b; do
    if ! grep -Fx "screenshots: OK" "$logs/$name.log" >/dev/null; then
      echo "check: スクリーンショットの場面が作れなかった（$name）" >&2
      exit 1
    fi
  done
fi
echo "check: OK"
