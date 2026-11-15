#!/usr/bin/env bash
# 撮った画像を、画像の置き場所のブランチ screenshots へ push し、PR に貼る Markdown を出す。
# 作業中のブランチと作業ツリーには触らない（一時のディレクトリで push する）。使い方は docs/screenshots.md。
#
#   tools/publish_screenshots.sh <PR の番号> <画像のディレクトリか、画像のファイル…>
#
# 置き場所は pr-<PR の番号>/<いまの HEAD の短い id>/<ファイル名>。同じ場所が既にあれば -2、-3 … を付ける
# （同じ URL の中身は差し替えない。GitHub は画像をキャッシュするので、差し替えると古い絵が出る）。
set -euo pipefail

BRANCH=screenshots
PR="${1:?PR の番号を指定する}"
shift
[ "$#" -gt 0 ] || { echo "画像のディレクトリかファイルを指定する" >&2; exit 1; }
[[ "$PR" =~ ^[0-9]+$ ]] || { echo "PR の番号が数でない: $PR" >&2; exit 1; }

repo_root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
remote="$(git -C "$repo_root" remote get-url origin)"
commit="$(git -C "$repo_root" rev-parse --short HEAD)"
# https://github.com/<owner>/<repo>(.git) か、プロキシ経由の …/git/<owner>/<repo> から owner/repo を取る。
slug="$(sed -E 's#\.git$##; s#^.*[/:]([^/]+)/([^/]+)$#\1/\2#' <<<"$remote")"

files=()
for arg in "$@"; do
  if [ -d "$arg" ]; then
    while IFS= read -r f; do files+=("$f"); done < <(find "$arg" -maxdepth 1 -type f \( -name '*.jpg' -o -name '*.png' -o -name '*.webp' -o -name '*.gif' \) | sort)
  else
    files+=("$arg")
  fi
done
[ "${#files[@]}" -gt 0 ] || { echo "画像が無い" >&2; exit 1; }
for f in "${files[@]}"; do
  [ -f "$f" ] || { echo "ファイルが無い: $f" >&2; exit 1; }
  size=$(stat -c %s "$f")
  [ "$size" -le 1048576 ] || { echo "1 MB を超える画像は置かない: $f ($size バイト)" >&2; exit 1; }
done

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
git -C "$work" init -q
git -C "$work" remote add origin "$remote"
git -C "$work" config user.name "$(git -C "$repo_root" config user.name || echo screenshots)"
git -C "$work" config user.email "$(git -C "$repo_root" config user.email || echo screenshots@localhost)"

readme() {
  cat >"$work/README.md" <<'README'
# screenshots

PR に貼る画面のスクリーンショットの置き場所。`main` とはつながらない独立のブランチ。

- 作業のセッションが `tools/publish_screenshots.sh` で直接 push する（PR は作らない。`main` へはマージしない）。
- 置き場所は `pr-<PR の番号>/<コミットの短い id>/`。追記するだけで、置いたものは差し替えない。
- 手入れは要らない。消しても、困るのは古い PR の画像が出なくなることだけ。
README
}

# 別のセッションと同時に push してぶつかったら、取り込み直してやり直す。
for attempt in 1 2 3 4 5; do
  rm -rf "$work/pr-$PR" 2>/dev/null || true
  if git -C "$work" fetch -q --depth 1 origin "$BRANCH" 2>/dev/null; then
    git -C "$work" checkout -q -B "$BRANCH" FETCH_HEAD
    git -C "$work" reset -q --hard FETCH_HEAD
  else
    git -C "$work" checkout -q --orphan "$BRANCH"
    git -C "$work" rm -rq --cached . 2>/dev/null || true
    readme
    git -C "$work" add README.md
  fi

  dir="pr-$PR/$commit"
  n=2
  while [ -e "$work/$dir" ]; do
    dir="pr-$PR/$commit-$n"
    n=$((n + 1))
  done
  mkdir -p "$work/$dir"
  for f in "${files[@]}"; do
    cp "$f" "$work/$dir/"
  done
  git -C "$work" add "$dir"
  git -C "$work" commit -qm ":camera_flash: Add screenshots for #$PR ($commit)"

  if git -C "$work" push -q origin "HEAD:refs/heads/$BRANCH" 2>"$work/push.log"; then
    echo "screenshots: $BRANCH/$dir に置いた" >&2
    for f in "${files[@]}"; do
      name="$(basename "$f")"
      echo "![${name%.*}](https://raw.githubusercontent.com/$slug/$BRANCH/$dir/$name)"
    done
    exit 0
  fi
  cat "$work/push.log" >&2
  echo "screenshots: push できなかった。取り込み直してやり直す（$attempt 回目）" >&2
  # 失敗したコミットは捨てる（次の回で取り込み直したところから作り直す）。
  git -C "$work" checkout -q --detach 2>/dev/null || true
  git -C "$work" branch -q -D "$BRANCH" 2>/dev/null || true
  rm -rf "$work/pr-$PR"
  sleep $((attempt * 2))
done
echo "screenshots: push できなかった" >&2
exit 1
