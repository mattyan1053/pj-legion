#!/usr/bin/env bash
# クラシックの編曲の BGM を、楽譜のデータから ogg まで作る（README.md）。
#   tools/classical_bgm/build.sh [書き出す先（既定: assets/audio/classical）]
# 要るもの: lilypond（2.24）、fluidsynth、ffmpeg（libvorbis）、Python の mido・numpy・scipy・soundfile・pyloudnorm、
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
#    winter: 「冬」第 1 楽章、summer: 「夏」第 3 楽章 Presto。
for piece in winter:winter1 summer:summer3; do
	dir="${piece%%:*}"; name="${piece##*:}"
	cp "$here/$dir"/*.ly "$work"/
	# 「夏」の原稿の頭の old-relative（2.24 に無い）は消す。和音は \relative の外にだけあるので、音の高さは変わらない。
	sed -i "/ly:set-option 'old-relative/d" "$work/$name"*.ly
	convert-ly -e -f 2.12.3 "$work/$name"*.ly "$work/$dir-header.ly" >/dev/null 2>&1
	sed -i 's/^\\version "2.12.3"/\\version "2.24.0"/' "$work/$name"*.ly
	(cd "$work" && lilypond -s -dmidi-extension=mid -o "$name" "$name-midi.ly")
done

# 2. 版ごとに編曲し、音にして、ループする ogg にする（版 -> 楽譜）。
#    緩急のある版（winter_wave_*）は、強い所の山を抑えて大きさをそろえ（finish.py の limit）、
#    旋律だけ・伴奏だけの音も書き出して、区切りごとの緩急と主旋律を測る（sections.py）。MEASURE=1 なら、ほかの版も測る。
render() { fluidsynth -ni -q -g 0.6 -r 44100 -R 1 -C 0 -T wav -F "$2" "$sf2" "$1" >/dev/null; }
for pair in winter_wave_heavy:winter1 winter_wave_mid:winter1 winter_wave_full:winter1 winter_drive2:winter1 winter_grave:winter1 summer_storm:summer3; do
	version="${pair%%:*}"; score="${pair##*:}"
	python3 "$here/arrange.py" "$work/$score.mid" "$version" "$work/$version.mid"
	render "$work/$version.mid" "$work/$version.wav"
	mode=""; case "$version" in winter_wave_*) mode="limit";; esac
	python3 "$here/finish.py" "$work/$version.wav" "$(cat "$work/$version.mid.loop")" "$out/$version.ogg" $mode
	rm -f "$out/$version.loop.wav"
	if [ -n "$mode" ] || [ -n "${MEASURE:-}" ]; then
		render "$work/$version.melody.mid" "$work/$version.melody.wav"
		render "$work/$version.backing.mid" "$work/$version.backing.wav"
		python3 "$here/sections.py" "$work/$version.wav" "$work/$version.melody.wav" "$work/$version.backing.wav" "$work/$version.mid.sections"
	fi
done
