#!/usr/bin/env bash
# クラシックの編曲の BGM を、楽譜のデータから ogg まで作る（README.md）。
#   tools/classical_bgm/build.sh [書き出す先（既定: assets/audio/classical）]
# 要るもの: lilypond（2.24）、fluidsynth、ffmpeg（libvorbis）、Python の mido・numpy・soundfile・pyloudnorm、
# サウンドフォント FluidR3_GM（MIT。apt の fluid-soundfont-gm）。別のものを使うなら SF2 にパスを入れる。
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
out="${1:-$root/assets/audio/classical}"
sf2="${SF2:-/usr/share/sounds/sf2/FluidR3_GM.sf2}"
[ -f "$sf2" ] || { echo "サウンドフォントが無い: $sf2（apt install fluid-soundfont-gm）" >&2; exit 1; }
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$out"

# 1. 楽譜（Mutopia の LilyPond 2.12 の原稿）を 2.24 の書き方に直し、パートごとの MIDI にする。
cp "$here"/winter/*.ly "$work"/
convert-ly -e -f 2.12.3 "$work"/winter1*.ly "$work"/winter-header.ly >/dev/null 2>&1
sed -i 's/^\\version "2.12.3"/\\version "2.24.0"/' "$work"/winter1*.ly
(cd "$work" && lilypond -s -dmidi-extension=mid -o winter1 winter1-midi.ly)

# 2. 版ごとに編曲し、音にして、ループする ogg にする。
for version in winter_strings winter_boss winter_heavy; do
	python3 "$here/arrange.py" "$work/winter1.mid" "$version" "$work/$version.mid"
	fluidsynth -ni -q -g 0.6 -r 44100 -R 1 -C 0 -T wav -F "$work/$version.wav" "$sf2" "$work/$version.mid" >/dev/null
	python3 "$here/finish.py" "$work/$version.wav" "$(cat "$work/$version.mid.loop")" "$out/$version.ogg"
	rm -f "$out/$version.loop.wav"
done
