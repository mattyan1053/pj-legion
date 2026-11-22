#!/usr/bin/env bash
# PreToolUse（Bash）のフック。`git push` の前に tools/check.sh を回し、落ちたら push を止める（終了コード 2）。
# - godot が無い環境、tools/check.sh が無いブランチでは何もせず通す。
# - 最後に通したコミット（と未コミットの差分）を .git の中に覚え、同じ状態では回し直さない。
# - 環境変数 CHECK_GODOT で godot の場所を替えられる（既定は PATH の godot）。
set -uo pipefail

input="$(cat)"
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
else
  cmd="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)"
fi

# `git push` を含むコマンドだけ見る（`git -C x push` なども拾う）。
printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+push([[:space:]]|$)' || exit 0

godot="${CHECK_GODOT:-godot}"
command -v "$godot" >/dev/null 2>&1 || exit 0
# push 先のチェックアウトを決める: `git -C <dir> push`、`cd <dir> && git push`、なければフックの cwd。
target=""
if [[ "$cmd" =~ git[[:space:]]+-C[[:space:]]+(\"([^\"]+)\"|\'([^\']+)\'|([^[:space:]]+))[[:space:]] ]]; then
  target="${BASH_REMATCH[2]:-${BASH_REMATCH[3]:-${BASH_REMATCH[4]}}}"
elif [[ "$cmd" =~ (^|[;&|[:space:]])cd[[:space:]]+(\"([^\"]+)\"|\'([^\']+)\'|([^[:space:];\&|]+)) ]]; then
  target="${BASH_REMATCH[3]:-${BASH_REMATCH[4]:-${BASH_REMATCH[5]}}}"
fi
base="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[ -n "$base" ] || base="$PWD"
if [ -n "$target" ]; then
  case "$target" in /*) ;; *) target="$base/$target" ;; esac
  base="$target"
fi
cd "$base" 2>/dev/null || exit 0
root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -f "$root/tools/check.sh" ] || exit 0
cd "$root"

state="$(git rev-parse HEAD 2>/dev/null)-$(git diff HEAD 2>/dev/null | sha1sum | cut -c1-12)"
stamp="$(git rev-parse --git-dir)/pre-push-check-ok"
if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$state" ]; then
  exit 0
fi

if out="$(bash tools/check.sh "$godot" 2>&1)"; then
  printf '%s' "$state" > "$stamp"
  exit 0
fi

{
  echo "push を止めました: tools/check.sh が落ちています。直してから push してください。"
  printf '%s\n' "$out" | tail -n 40
} >&2
exit 2
