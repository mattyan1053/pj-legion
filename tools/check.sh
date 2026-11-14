#!/usr/bin/env bash
# リポジトリの置き方を確かめ、プロジェクトを画面なしで取り込み、テスト（tests/）を実行し、
# メインシーンを少しだけ動かして、スクリプトのエラーが出ないことを確かめる。CI と手元で同じものを使う。
#
#   tools/check.sh /path/to/godot
set -euo pipefail

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
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

# スクリプトが読み込めないと Godot は終わらずに待ち続けることがあるので、時間で打ち切る。
run() {
  timeout 120 "$GODOT" --headless --path . "$@" 2>&1 | tee -a "$log"
}

run --import
run -s res://tools/run_tests.gd
run --quit-after 60

if grep -E "SCRIPT ERROR|Parse Error|^ERROR" "$log" >/dev/null; then
  echo "check: エラーが出ています" >&2
  exit 1
fi
echo "check: OK"
