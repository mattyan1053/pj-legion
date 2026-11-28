#!/usr/bin/env bash
# クラシックの編曲の BGM を、楽譜のデータから ogg まで作る（README.md）。
#   tools/classical_bgm/build.sh [書き出す先（既定: assets/audio/classical）]
# WORK=<場所> を付けると、途中の MIDI と WAV をそこに残す（付けなければ消す）。
# VERSIONS="<版>:<楽譜> ..." を付けると、その版だけ作る（例: VERSIONS="winter_dark_grave2:winter1"）。
# 要るもの: lilypond（2.24）、fluidsynth、ffmpeg（libvorbis）、Python の mido・numpy・scipy・soundfile・pyloudnorm、
# サウンドフォント FluidR3_GM（MIT。apt の fluid-soundfont-gm）。別のものを使うなら SF2 にパスを入れる。
# 音色の組で鳴らす版（新重・新電。tones.py）は、楽器ごとに別の音源を使う。場所は環境変数で渡す（無ければ既定の場所）:
#   SF2_MUSESCORE  MuseScore_General_Full.sf2（MIT。apt の musescore-general-soundfont-lossless）
#   SF2_DRUMS      Red_Zeppelin_4_LV2.sf2（AVL Drumkits、CC BY-SA 3.0。apt の avldrums.lv2-soundfont）
#   VSCO           VSCO 2 CE（CC0）を置いた場所（README.md の「要るもの」）
# 楽器ごとの音源の表は tones.py の TONES。音源そのものはリポジトリに入れない。
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
out="${1:-$root/assets/audio/classical}"
sf2="${SF2:-/usr/share/sounds/sf2/FluidR3_GM.sf2}"
[ -f "$sf2" ] || { echo "サウンドフォントが無い: $sf2（apt install fluid-soundfont-gm）" >&2; exit 1; }
work="${WORK:-$(mktemp -d)}"
[ -n "${WORK:-}" ] || trap 'rm -rf "$work"' EXIT
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
#    緩急のある版（winter_wave_*）と暗く重い版（winter_dark_*）は、強い所の山がつかえたら抑えて大きさをそろえ（finish.py の limit）、
#    旋律だけ・伴奏だけの音も書き出して、区切りごとの緩急と主旋律を測る（sections.py）。MEASURE=1 なら、ほかの版も測る。
#    音色の組で鳴らす版（arrange.py が .tone を書く）は、MIDI がもとの版と同じ（音符を変えていない）ことを確かめてから、
#    tones.py で楽器ごとに音源を選んで鳴らす。楽器ごとの音は $work/<版>.stems/ に残す（measure.py --wobble の STEMS 用）。
render() {
	if [ -f "$work/$version.mid.tone" ]; then
		read -r tone same < "$work/$version.mid.tone"
		python3 "$here/arrange.py" "$work/$score.mid" "$same" "$work/$version.same.mid" >/dev/null
		cmp "$work/$version.mid" "$work/$version.same.mid" || { echo "$version: 編曲が $same と違う" >&2; exit 1; }
		stems=(); [ "$1" = "$work/$version.mid" ] && stems=(--stems "$work/$version.stems")
		python3 "$here/tones.py" "$1" "$tone" "$2" "${stems[@]}"
	else
		fluidsynth -ni -q -g 0.6 -r 44100 -R 1 -C 0 -T wav -F "$2" "$sf2" "$1" >/dev/null
	fi
}
for pair in ${VERSIONS:-winter_dark_grave:winter1 winter_dark_grave2:winter1 winter_dark_drive:winter1 winter_dark_drive2:winter1 winter_drive2:winter1 winter_grave:winter1 summer_storm:summer3}; do
	version="${pair%%:*}"; score="${pair##*:}"
	python3 "$here/arrange.py" "$work/$score.mid" "$version" "$work/$version.mid"
	render "$work/$version.mid" "$work/$version.wav"
	mode=""; case "$version" in winter_wave_*|winter_dark_*) mode="limit";; esac
	python3 "$here/finish.py" "$work/$version.wav" "$(cat "$work/$version.mid.loop")" "$out/$version.ogg" $mode
	rm -f "$out/$version.loop.wav"
	if [ -n "$mode" ] || [ -n "${MEASURE:-}" ]; then
		render "$work/$version.melody.mid" "$work/$version.melody.wav"
		render "$work/$version.backing.mid" "$work/$version.backing.wav"
		python3 "$here/sections.py" "$work/$version.wav" "$work/$version.melody.wav" "$work/$version.backing.wav" "$work/$version.mid.sections"
	fi
done
