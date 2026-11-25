#!/usr/bin/env python3
"""楽譜の MIDI（パートごと。LilyPond の書き出し）を、ゲームの BGM の編曲にした MIDI にする。

使い方: arrange.py <楽譜の MIDI> <版の名前> <書き出す MIDI>
版は VERSIONS（テンポ、使う小節、楽器の割り当て）。手順の全体は build.sh と README.md。

- 楽譜の MIDI は、トラックの名前でパートを見分ける（solo / violinone / violintwo / viola / cello）。
- 小節は 4/4（0 始まりで数える）。全合奏の小節（第 1 ヴァイオリンが鳴る小節）を f、独奏の小節の伴奏を p にする。
- 足す楽器（コントラバス、チェンバロ、ティンパニ、金管、合唱）は、楽譜の音から機械的に作る（下の関数）。
- 生楽器のサンプルの GM 音色だけを使う（シンセやビット音源の音色は使わない）。
"""
import sys

import mido

PARTS = ["solo", "violinone", "violintwo", "viola", "cello"]
BEATS_PER_BAR = 4
OUT_TPB = 480

# GM の音色の番号（0 始まり）。
VIOLIN, VIOLA, CELLO, CONTRABASS = 40, 41, 42, 43
HARP, TIMPANI, STRINGS, SLOW_STRINGS = 46, 47, 48, 49
CHOIR, TROMBONE, TUBA, HORN, HARPSICHORD = 52, 57, 58, 60, 6

# 版。bars は鳴らす小節の並び（range の組）。ループは、並びの終わりから頭へ戻る。
VERSIONS = {
    # 原曲に近い形: 弦の合奏と独奏ヴァイオリンに、通奏低音（チェンバロ）とコントラバスを足しただけ。
    "winter_strings": {
        "tempo": 104,
        "bars": [range(0, 63)],
        "layers": ["solo", "strings", "cello", "contrabass", "harpsichord"],
    },
    # ボス戦の形: 速めにし、ティンパニ・低音の金管・ホルンを全合奏に足す。終わりの小節にティンパニの連打を置き、頭へつなぐ。
    "winter_boss": {
        "tempo": 112,
        "bars": [range(0, 63)],
        "layers": ["solo", "strings", "cello", "contrabass", "timpani", "low_brass", "horns", "choir_end", "pickup"],
    },
    # 重い形: テンポを落とし、合唱と低音の金管とティンパニで重くする。長さを収めるため、中ほどの独奏（26〜54 小節）を抜く。
    "winter_heavy": {
        "tempo": 80,
        "bars": [range(0, 26), range(55, 63)],
        "layers": ["solo", "strings", "cello", "contrabass", "timpani", "low_brass", "choir", "pickup"],
    },
}

# 楽器の並び: 名前 -> (チャンネル, 音色, 音量 CC7, 左右 CC10, 残響 CC91)。チャンネル 9（打楽器）は使わない。
CHANNELS = {
    "solo": (0, VIOLIN, 110, 58, 50),
    "violin1": (1, STRINGS, 100, 40, 60),
    "violin2": (2, STRINGS, 96, 52, 60),
    "viola": (3, STRINGS, 92, 76, 60),
    "cello": (4, CELLO, 100, 88, 55),
    "contrabass": (5, CONTRABASS, 96, 92, 55),
    "harpsichord": (6, HARPSICHORD, 72, 70, 45),
    "timpani": (7, TIMPANI, 110, 64, 70),
    "trombone": (8, TROMBONE, 82, 84, 70),
    "tuba": (10, TUBA, 80, 80, 70),
    "horns": (11, HORN, 84, 36, 75),
    "choir": (12, CHOIR, 78, 64, 85),
}


def read_parts(path):
    """パートの名前 -> [(始まり, 終わり, 音の高さ)]（拍の単位、小数）。"""
    mid = mido.MidiFile(path)
    tpb = mid.ticks_per_beat
    parts = {}
    for track in mid.tracks:
        name = track.name.rstrip(":")
        if name not in PARTS:
            continue
        now, sounding, notes = 0, {}, []
        for msg in track:
            now += msg.time
            if msg.type == "note_on" and msg.velocity > 0:
                sounding.setdefault(msg.note, []).append(now)
            elif msg.type in ("note_off", "note_on"):
                starts = sounding.get(msg.note)
                if starts:
                    start = starts.pop(0)
                    notes.append((start / tpb, now / tpb, msg.note))
        parts[name] = sorted(notes)
    missing = [p for p in PARTS if p not in parts]
    if missing:
        raise SystemExit(f"楽譜の MIDI にパートが無い: {missing}")
    return parts


def bar_of(beat):
    return int(beat // BEATS_PER_BAR)


def remap(bars_list):
    """元の小節 -> 鳴らす位置（小節）の表。"""
    table, at = {}, 0
    for r in bars_list:
        for b in r:
            table[b] = at
            at += 1
    return table, at


def sounding_at(notes, beat):
    return [n for (s, e, n) in notes if s <= beat + 1e-6 < e]


def into_range(pitch, low, high):
    while pitch < low:
        pitch += 12
    while pitch > high:
        pitch -= 12
    return pitch


class Score:
    """書き出す音の列。チャンネルごとに (始まり（拍）, 長さ（拍）, 高さ, 強さ)。"""

    def __init__(self):
        self.notes = {name: [] for name in CHANNELS}

    def add(self, layer, start, length, pitch, velocity):
        if length <= 0:
            return
        velocity = max(1, min(127, int(velocity)))
        self.notes[layer].append((start, length, pitch, velocity))


def arrange(parts, version):
    spec = VERSIONS[version]
    table, total_bars = remap(spec["bars"])
    tutti = {b for (s, e, n) in parts["violinone"] for b in [bar_of(s)]}
    layers = set(spec["layers"])
    score = Score()
    last_bar = max(table)

    def place(beat):
        """元の拍 -> 鳴らす拍（使わない小節なら None）。"""
        b = bar_of(beat)
        if b not in table:
            return None
        return table[b] * BEATS_PER_BAR + (beat - b * BEATS_PER_BAR)

    def loudness(bar):
        """小節の強さ（0〜1）。初めの 4 小節は、パートが重なるにつれて強める。"""
        if bar < 4:
            return 0.55 + 0.1 * bar
        return 0.92 if bar in tutti else 0.62

    def copy(part, layer, scale=1.0, shift=0, low=None):
        for (s, e, n) in parts[part]:
            at = place(s)
            if at is None:
                continue
            end_bar = bar_of(s) + 1
            length = min(e, end_bar * BEATS_PER_BAR) - s
            pitch = n + shift
            if low is not None and pitch < low:
                continue
            score.add(layer, at, length, pitch, 127 * loudness(bar_of(s)) * scale)

    # 弦（どの版も）。独奏の小節は独奏を立て、全合奏では独奏も合奏に混ぜる。
    for (s, e, n) in parts["solo"]:
        at = place(s)
        if at is None:
            continue
        bar = bar_of(s)
        vel = 112 if bar not in tutti else 96
        score.add("solo", at, min(e, (bar + 1) * BEATS_PER_BAR) - s, n, vel)
    copy("violinone", "violin1")
    copy("violintwo", "violin2", 0.95)
    copy("viola", "viola", 0.95)
    copy("cello", "cello")
    if "contrabass" in layers:
        copy("cello", "contrabass", 0.9, shift=-12, low=28)

    # 拍ごとの和音（チェンバロ・ホルン・合唱が使う）。
    def chord(beat):
        bass = sounding_at(parts["cello"], beat)
        upper = sounding_at(parts["violinone"], beat) + sounding_at(parts["violintwo"], beat) + sounding_at(parts["viola"], beat)
        return (min(bass) if bass else None), sorted(set(upper))

    source_bars = sorted(table)
    for bar in source_bars:
        is_tutti = bar in tutti
        for beat_in_bar in range(BEATS_PER_BAR):
            beat = bar * BEATS_PER_BAR + beat_in_bar
            at = place(beat)
            bass, upper = chord(beat)
            strong = beat_in_bar in (0, 2)
            if "harpsichord" in layers and (bass is not None or upper):
                # 通奏低音: 低音を 1 つと、上の声の音を中ほどの高さで。少しずらして鳴らす（つま弾くように）。
                pcs = sorted({into_range(p, 60, 71) for p in upper})
                tones = ([into_range(bass, 43, 54)] if bass is not None else []) + pcs
                for i, p in enumerate(tones):
                    score.add("harpsichord", at + 0.02 * i, 0.9 - 0.02 * i, p, 70 if strong else 58)
            if not strong:
                continue
            if "timpani" in layers and bass is not None and (is_tutti or bar < 4):
                # ティンパニ: 全合奏の小節の 1 拍目と 3 拍目に、低音の高さで（F2〜F3 に収める）。初めの 4 小節は 8 分音符で強める。
                p = into_range(bass, 41, 53)
                if bar < 4:
                    for k in range(4):
                        score.add("timpani", at + 0.5 * k, 0.45, p, 50 + 12 * bar + 4 * k)
                else:
                    score.add("timpani", at, 0.9, p, 112 if beat_in_bar == 0 else 92)
            if "low_brass" in layers and bass is not None and is_tutti:
                # 低音の金管: 低音を 2 拍ずつ伸ばす（トロンボーンと、1 オクターブ下のチューバ）。
                p = into_range(bass, 40, 55)
                score.add("trombone", at, 1.9, p, 92)
                score.add("tuba", at, 1.9, p - 12, 88)
            if "horns" in layers and is_tutti and upper:
                # ホルン: 内声（第 2 ヴァイオリンとヴィオラ）を 2 拍ずつ伸ばす。
                inner = sounding_at(parts["violintwo"], beat) + sounding_at(parts["viola"], beat)
                for p in sorted({into_range(p, 53, 69) for p in inner}):
                    score.add("horns", at, 1.9, p, 86)
            choir_here = "choir" in layers and (is_tutti or bar < 4)
            choir_here = choir_here or ("choir_end" in layers and is_tutti and bar >= 52)
            if choir_here and upper:
                # 合唱: 上の声の和音を 2 拍ずつ伸ばす（低めの音域で、暗く）。
                for p in sorted({into_range(p, 55, 72) for p in upper}):
                    score.add("choir", at, 1.95, p, 80 if bar >= 4 else 50 + 8 * bar)

    if "pickup" in layers and "timpani" in layers:
        # ループの終わりの小節の 3〜4 拍目に、属音（C）のティンパニの連打で強めていき、頭（低音の F）へつなぐ。
        end_at = table[last_bar] * BEATS_PER_BAR
        for k in range(16):
            score.add("timpani", end_at + 2 + 0.125 * k, 0.12, 48, 46 + 4 * k)

    return score, total_bars * BEATS_PER_BAR, spec["tempo"]


def write_midi(score, total_beats, tempo, path):
    mid = mido.MidiFile(type=1, ticks_per_beat=OUT_TPB)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(tempo), time=0))
    meta.append(mido.MetaMessage("time_signature", numerator=4, denominator=4, time=0))
    # ループの終わりのあとに 2 小節、何も鳴らさない間を置く（書き出しで残響の尾まで録るため。finish.py が頭に重ねる）。
    meta.append(mido.MetaMessage("marker", text="loop_end", time=int(total_beats * OUT_TPB)))
    meta.append(mido.MetaMessage("end_of_track", time=int(2 * BEATS_PER_BAR * OUT_TPB)))
    mid.tracks.append(meta)
    for layer, (ch, program, volume, pan, reverb) in CHANNELS.items():
        notes = score.notes[layer]
        if not notes:
            continue
        track = mido.MidiTrack()
        track.append(mido.MetaMessage("track_name", name=layer, time=0))
        events = [(0, 0, mido.Message("program_change", channel=ch, program=program)),
                  (0, 0, mido.Message("control_change", channel=ch, control=7, value=volume)),
                  (0, 0, mido.Message("control_change", channel=ch, control=10, value=pan)),
                  (0, 0, mido.Message("control_change", channel=ch, control=91, value=reverb)),
                  (0, 0, mido.Message("control_change", channel=ch, control=93, value=0))]
        for (start, length, pitch, vel) in notes:
            on = int(round(start * OUT_TPB))
            off = max(on + 1, int(round((start + length) * OUT_TPB)) - 4)
            events.append((on, 2, mido.Message("note_on", channel=ch, note=pitch, velocity=vel)))
            events.append((off, 1, mido.Message("note_off", channel=ch, note=pitch, velocity=0)))
        events.sort(key=lambda e: (e[0], e[1]))
        now = 0
        for (tick, _, msg) in events:
            track.append(msg.copy(time=tick - now))
            now = tick
        mid.tracks.append(track)
    mid.save(path)


def main():
    if len(sys.argv) != 4 or sys.argv[2] not in VERSIONS:
        raise SystemExit(f"使い方: arrange.py <楽譜の MIDI> <{'|'.join(VERSIONS)}> <書き出す MIDI>")
    parts = read_parts(sys.argv[1])
    score, total_beats, tempo = arrange(parts, sys.argv[2])
    write_midi(score, total_beats, tempo, sys.argv[3])
    seconds = total_beats * 60.0 / tempo
    with open(sys.argv[3] + ".loop", "w") as f:
        f.write(f"{seconds:.6f}\n")
    print(f"{sys.argv[2]}: ♩={tempo}, {total_beats // BEATS_PER_BAR} 小節, ループ {seconds:.2f} 秒")


if __name__ == "__main__":
    main()
