#!/usr/bin/env bash
# リポジトリの置き方を確かめ、プロジェクトを画面なしで取り込み、テスト（tests/）を実行し、
# メインシーンで自動の対戦（prototype/autoplay.gd）を最後まで進めて、スクリプトのエラーが出ないことを確かめる。
# CI と手元で同じものを使う。テストと自動の対戦は、取り込みのあと並べて回す。
#
#   tools/check.sh /path/to/godot          PR ごとの検査（CI の check）
#   tools/check.sh --full /path/to/godot   長い検査（時間の掛かるテストと、自動の対戦のほかのステージも回す）
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

# スクリプトが読み込めないと Godot は終わらずに待ち続けることがあるので、時間で打ち切る。
run() {
  local name="$1"
  shift
  timeout 120 "$GODOT" --headless --path . "$@" >"$logs/$name.log" 2>&1
}

run import --import || { cat "$logs/import.log"; exit 1; }
cat "$logs/import.log"
# テストと自動の対戦は互いに関わらないので、並べて回す（ログは混ぜずに、終わってから順に出す）。
run tests -s res://tools/run_tests.gd -- $full &
tests_pid=$!
# 自動の対戦。画面の描画を待たずに進める（--fixed-fps）。終わらなければ、コマ数で打ち切る。
run autoplay --fixed-fps 60 --quit-after 20000 -- --autoplay $full &
autoplay_pid=$!
status=0
wait "$tests_pid" || status=1
wait "$autoplay_pid" || status=1
cat "$logs/tests.log" "$logs/autoplay.log"
[ "$status" = 0 ] || { echo "check: テストか自動の対戦が失敗した" >&2; exit 1; }

if cat "$logs"/*.log | grep -E "SCRIPT ERROR|Parse Error|^ERROR" >/dev/null; then
  echo "check: エラーが出ています" >&2
  exit 1
fi
if ! grep -F "autoplay: OK" "$logs/autoplay.log" >/dev/null; then
  echo "check: 自動の対戦が最後まで進まなかった" >&2
  exit 1
fi
echo "check: OK"
