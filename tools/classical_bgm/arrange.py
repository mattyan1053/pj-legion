#!/usr/bin/env python3
"""楽譜の MIDI（パートごと。LilyPond の書き出し）を、戦闘曲の型に組み直した MIDI にする。

使い方: arrange.py <楽譜の MIDI> <版の名前> <書き出す MIDI>
版は VERSIONS。手順の全体は build.sh と README.md。

原曲の流れを頭から追わない。楽譜から強い所（同音の刻みの合奏、独奏の速い走句、終わりの総奏）を小節の単位で切り出し、
並べ直して（繰り返しも可）、その上に戦闘曲の型の層を足す。

- 楽譜の MIDI は、トラックの名前でパートを見分ける（solo / violinone / violintwo / viola / cello）。
- 和声は拍ごとに楽譜から取る: 根音 = チェロ（休みならほかの下の声）のいちばん低い音、和音 = 独奏を除く声の音。
- 足す層（どれも楽譜の和声と音から機械的に作る）:
  - bass: 根音のオスティナート（4 分・8 分・16 分・オクターブの跳ね）。シンセベース／エレキベース／コントラバス／チューバ。
  - timpani: 根音を拍で。区切りの前に連打。
  - drums: 打楽器（チャンネル 10）。orchestra（大太鼓・スネア・シンバル）か kit（ドラムキット）。
  - stabs: 金管の和音の短い打ち込み（決まった拍の型で）。
  - pad: 和音の持続（シンセのパッド・合唱）。小節の頭で鳴らし直す。
  - lead: 独奏の走句を別の楽器で重ねる（トリルの続く小節は第 1 ヴァイオリンの線を重ねる）。
  - power: 根音と 5 度の刻み（歪んだギター）。
- 弦は短く切る（伸ばす音は、刻みの細かさ grid で刻み直す）。弱い所を作らない（どの小節も f）。
- 区切り（section）ごとに level（1〜3）を持ち、上がるほど打楽器と打ち込みが細かくなる（積み上げ）。
"""
import sys

import mido

PARTS = ["solo", "violinone", "violintwo", "viola", "cello"]
OUT_TPB = 480
DRUM_CH = 9

# GM の音色の番号（0 始まり）。
VIOLIN, VIOLA, CELLO, CONTRABASS, TIMPANI, STRINGS = 40, 41, 42, 43, 47, 48
SYNTH_STRINGS, CHOIR, TRUMPET, TROMBONE, TUBA, HORN, BRASS = 50, 52, 56, 57, 58, 60, 61
FINGER_BASS, SYNTH_BASS, SYNTH_BASS_2, DIST_GUITAR = 33, 38, 39, 30
FLUTE, PICCOLO, SAW_LEAD, POLY_PAD, WARM_PAD = 73, 72, 81, 90, 89

# 打楽器（GM のキーの番号）。
KICK, BASS_DRUM, SNARE, SNARE2, HAT, HAT_OPEN, CRASH, CRASH2, RIDE = 36, 35, 38, 40, 42, 46, 49, 57, 51
TOMS = [50, 48, 47, 45, 43, 41]

PIECES = {
    # ヴィヴァルディ「冬」第 1 楽章（ヘ短調、4/4）。
    "winter1": {"beats": 4},
    # ヴィヴァルディ「夏」第 3 楽章 Presto（ト短調、3/4）。
    "summer3": {"beats": 3},
}

# 版。form は鳴らす区切りの並び: (始めの小節, 終わりの小節（含まない）, level)。小節は 0 始まり。並びの終わりから頭へループする。
# layers は層の名前 -> 楽器（CHANNELS の名前）や型。
VERSIONS = {
    # (a) オーケストラで圧を足した版: 低弦とティンパニのオスティナート、金管の打ち込み、スネアの刻み、シンバル。
    "winter_brass": {
        "piece": "winter1", "tempo": 144, "grid": 0.5,
        "form": [(3, 11, 2), (19, 26, 2), (26, 32, 2), (32, 38, 2), (46, 55, 3), (55, 62, 3)],
        "strings": True, "solo": True,
        "bass": {"voice": "contrabass", "pattern": "8oct", "low": 28, "high": 40},
        "bass2": {"voice": "cello_ost", "pattern": "8", "low": 36, "high": 50},
        "timpani": {"pattern": "beat"},
        "drums": "orchestra",
        "stabs": {"voices": ["trumpet", "trombone", "horns"], "rhythm": [0, 1.5, 3], "min_level": 2},
        "bass3": {"voice": "tuba", "pattern": "4", "low": 29, "high": 41},
        "low_brass": True,
        "lead": {"voice": "piccolo", "shift": 0},
    },
    # (b) DTM 調: ドラムキット、太いシンセベースの 16 分、歪んだギターの刻み、シンセのパッドとリードを弦に重ねる。
    "winter_drive": {
        "piece": "winter1", "tempo": 152, "grid": 0.5,
        "form": [(3, 11, 2), (19, 26, 2), (46, 55, 3), (26, 32, 1), (32, 38, 2), (55, 62, 3)],
        "strings": True, "solo": True,
        "bass": {"voice": "synth_bass", "pattern": "16", "low": 28, "high": 40},
        "bass2": {"voice": "finger_bass", "pattern": "8oct", "low": 28, "high": 40},
        "power": {"min_level": 2},
        "drums": "kit",
        "pad": {"voice": "poly_pad"},
        "stabs": {"voices": ["brass"], "rhythm": [0, 1.5, 3], "min_level": 3},
        "lead": {"voice": "saw_lead", "shift": 0},
    },
    # (c) 遅く重い版: ♩=96。低音の 8 分とティンパニ、大太鼓の毎拍、低い金管、合唱。弦は 16 分で刻む。
    "winter_grave": {
        "piece": "winter1", "tempo": 96, "grid": 0.25,
        "form": [(3, 11, 2), (19, 26, 3), (46, 55, 2), (55, 62, 3)],
        "strings": True, "solo": True,
        "bass": {"voice": "contrabass", "pattern": "8oct", "low": 28, "high": 40},
        "bass2": {"voice": "synth_bass_2", "pattern": "8", "low": 28, "high": 40},
        "timpani": {"pattern": "8"},
        "drums": "heavy",
        "stabs": {"voices": ["trombone", "tuba", "horns"], "rhythm": [0, 2, 2.5], "min_level": 2},
        "pad": {"voice": "choir"},
        "low_brass": True,
    },
    # (d) 「夏」Presto: バロックの速い走句に、ドラムキットと太いベースと金管を重ねる（オーケストラと DTM の間）。
    "summer_storm": {
        "piece": "summer3", "tempo": 144, "grid": 0.5,
        "form": [(0, 4, 3), (5, 9, 3), (10, 19, 2), (19, 28, 2), (31, 39, 3), (54, 63, 2), (84, 96, 3), (119, 129, 3)],
        "strings": True, "solo": True,
        "bass": {"voice": "synth_bass", "pattern": "8oct", "low": 28, "high": 40},
        "bass2": {"voice": "contrabass", "pattern": "8", "low": 28, "high": 43},
        "timpani": {"pattern": "beat"},
        "drums": "kit",
        "stabs": {"voices": ["trumpet", "trombone", "horns"], "rhythm": [0, 1.5], "min_level": 2},
        "pad": {"voice": "synth_strings"},
        "lead": {"voice": "saw_lead", "shift": 0},
    },
}

# 楽器: 名前 -> (音色, 音量 CC7, 左右 CC10, 残響 CC91)。チャンネルは版ごとに、使う楽器にだけ割り当てる。
CHANNELS = {
    "solo": (VIOLIN, 112, 60, 40),
    "violin1": (STRINGS, 104, 40, 45),
    "violin1b": (VIOLIN, 92, 34, 40),
    "violin2": (STRINGS, 100, 52, 45),
    "viola": (STRINGS, 96, 76, 45),
    "cello": (CELLO, 108, 86, 40),
    "contrabass": (CONTRABASS, 112, 70, 35),
    "cello_ost": (CELLO, 100, 92, 35),
    "synth_bass": (SYNTH_BASS, 108, 64, 15),
    "synth_bass_2": (SYNTH_BASS_2, 104, 64, 15),
    "finger_bass": (FINGER_BASS, 104, 64, 15),
    "timpani": (TIMPANI, 116, 64, 50),
    "trumpet": (TRUMPET, 96, 50, 50),
    "trombone": (TROMBONE, 100, 80, 50),
    "tuba": (TUBA, 100, 72, 45),
    "horns": (HORN, 98, 30, 60),
    "brass": (BRASS, 96, 64, 50),
    "piccolo": (PICCOLO, 80, 46, 50),
    "saw_lead": (SAW_LEAD, 74, 58, 35),
    "poly_pad": (POLY_PAD, 70, 64, 60),
    "synth_strings": (SYNTH_STRINGS, 74, 64, 60),
    "choir": (CHOIR, 84, 64, 70),
    "power": (DIST_GUITAR, 74, 96, 25),
    "drums": (0, 118, 64, 30),
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


def into_range(pitch, low, high):
    while pitch < low:
        pitch += 12
    while pitch > high:
        pitch -= 12
    return pitch


class Score:
    """書き出す音の列。楽器ごとに (始まり（拍）, 長さ（拍）, 高さ, 強さ)。"""

    def __init__(self):
        self.notes = {}

    def add(self, layer, start, length, pitch, velocity):
        if length <= 0 or not 0 <= pitch <= 127:
            return
        velocity = max(1, min(127, int(velocity)))
        self.notes.setdefault(layer, []).append((start, length, pitch, velocity))


class Source:
    """楽譜を小節で引く。"""

    def __init__(self, parts, beats):
        self.parts, self.beats = parts, beats

    def bar_notes(self, part, bar):
        """小節の中の音: [(小節の中の拍, 長さ（小節の終わりで切る）, 高さ)]。"""
        lo, hi = bar * self.beats, (bar + 1) * self.beats
        return [(s - lo, min(e, hi) - s, n) for (s, e, n) in self.parts[part] if lo <= s < hi]

    def sounding(self, part, beat):
        return [n for (s, e, n) in self.parts[part] if s <= beat + 1e-6 < e]

    def harmony(self, beat):
        """(根音, 和音の音の高さの組)。鳴っていなければ (None, [])。"""
        for part in ["cello", "viola", "violintwo", "violinone"]:
            low = self.sounding(part, beat)
            if low:
                root = min(low)
                break
        else:
            root = None
        upper = set()
        for part in ["violinone", "violintwo", "viola", "cello"]:
            upper.update(self.sounding(part, beat))
        return root, sorted(upper)

    def density(self, part, bar):
        """小節の 1 拍あたりの音の数。"""
        return len(self.bar_notes(part, bar)) / self.beats


def drum_bar(score, kind, at, beats, level, first, last):
    """打楽器の 1 小節。first: 区切りの頭（シンバル）、last: 区切りの終わり（フィル）。"""
    d = lambda off, key, vel: score.add("drums", at + off, 0.2, key, vel)
    fill_from = beats - 1 if last else beats
    if first:
        d(0, CRASH, 122)
        if kind != "orchestra":
            d(0, CRASH2, 110)
    if kind == "kit":
        for k in range(int(fill_from * 2)):
            off = k * 0.5
            if level >= 3:
                d(off, KICK, 120 if off == int(off) else 100)
            elif off in (0, 1.5 if beats == 4 else 1.5, 2) and off < beats:
                d(off, KICK, 122)
            # ハイハット（level 3 は 16 分）。
            if level >= 3:
                d(off, HAT, 96 if off == int(off) else 76)
                d(off + 0.25, HAT, 64)
            else:
                d(off, HAT if off % 1 else HAT_OPEN if off == 0 and not first else HAT, 92 if off == int(off) else 70)
        for b in range(int(fill_from)):
            if (beats == 4 and b in (1, 3)) or (beats == 3 and b in (1, 2)):
                d(b, SNARE, 124)
            if b == 0:
                d(b, KICK, 127)
    elif kind == "orchestra":
        for b in range(int(fill_from)):
            if b == 0 or level >= 2 or (beats == 4 and b == 2):
                d(b, BASS_DRUM, 124 if b == 0 else 108)
            # スネアの刻み: 8 分（level 3 は「タタタ・タ」の 16 分）。拍の頭を強く。
            if level >= 3:
                for off, vel in ((0, 118), (0.25, 72), (0.5, 92), (0.75, 72)):
                    d(b + off, SNARE, vel)
            else:
                d(b, SNARE, 110)
                d(b + 0.5, SNARE, 80)
        if level >= 3 and not first:
            d(0, CRASH, 96)
    elif kind == "heavy":
        for b in range(int(fill_from)):
            d(b, BASS_DRUM, 127 if b in (0, 2) else 112)
            d(b, KICK, 110)
            if b in (1, 3):
                d(b, SNARE, 118)
            if level >= 3:
                d(b + 0.5, SNARE, 70)
                d(b + 0.75, BASS_DRUM, 96)
    if last:
        # フィル: 最後の拍を 16 分で（キットはタム、オーケストラはスネアと大太鼓）。
        base = beats - 1
        for k in range(4):
            if kind == "kit":
                d(base + 0.25 * k, TOMS[k + 1], 104 + 6 * k)
                d(base + 0.25 * k, KICK, 110)
            else:
                d(base + 0.25 * k, SNARE, 96 + 8 * k)
                d(base + 0.25 * k, BASS_DRUM, 100 + 6 * k)


def arrange(parts, version):
    spec = VERSIONS[version]
    beats = PIECES[spec["piece"]]["beats"]
    src = Source(parts, beats)
    grid = spec["grid"]
    score = Score()

    # 区切りを並べ、鳴らす位置（小節）を決める。
    placed = []  # (出す小節, 元の小節, level, 区切りの頭か, 区切りの終わりか)
    at = 0
    for (start, end, level) in spec["form"]:
        for bar in range(start, end):
            placed.append((at, bar, level, bar == start, bar == end - 1))
            at += 1
    total_bars = at

    def strings_copy(part, layer, vel, shift=0):
        """弦: 伸ばす音は grid で刻み直し、短い音は短く切る。拍の頭を強く。"""
        for (out, bar, level, _, _) in placed:
            base = out * beats
            for (off, length, n) in src.bar_notes(part, bar):
                accent = 14 if abs(off - round(off)) < 1e-6 else 0
                if length > grid * 1.5:
                    k = 0
                    while off + k * grid < off + length - 1e-6:
                        o = off + k * grid
                        a = 14 if abs(o - round(o)) < 1e-6 else 0
                        score.add(layer, base + o, grid * 0.7, n + shift, vel + a)
                        k += 1
                else:
                    score.add(layer, base + off, min(length * 0.8, 0.4), n + shift, vel + accent)

    if spec.get("strings"):
        strings_copy("violinone", "violin1", 96)
        strings_copy("violinone", "violin1b", 84)
        strings_copy("violintwo", "violin2", 92)
        strings_copy("viola", "viola", 90)
        strings_copy("cello", "cello", 100)

    if spec.get("solo"):
        for (out, bar, level, _, _) in placed:
            for (off, length, n) in src.bar_notes("solo", bar):
                score.add("solo", out * beats + off, min(length, 0.5) * 0.9, n, 108 + (10 if off == int(off) else 0))

    lead = spec.get("lead")
    if lead:
        for (out, bar, level, _, _) in placed:
            # トリル（1 拍に 8 つより多い）や、独奏の休みの小節は、第 1 ヴァイオリンの線を重ねる。
            part = "solo" if 0 < src.density("solo", bar) <= 8 else "violinone"
            notes = src.bar_notes(part, bar)
            for (off, length, n) in notes:
                score.add(lead["voice"], out * beats + off, min(length * 0.85, 0.45), n + lead["shift"],
                          100 + (12 if off == int(off) else 0))

    # 拍ごとの和声（足す層が使う）。休みの拍は前の和声を引き継ぐ。
    harmony = {}
    last = (None, [])
    for (out, bar, level, first, end) in placed:
        for b in range(beats):
            for half in (0, 0.5):
                root, upper = src.harmony(bar * beats + b + half)
                if root is None:
                    root, upper = last
                else:
                    last = (root, upper)
                harmony[(out, b + half)] = (root, upper)

    def root_at(out, off):
        return harmony[(out, off)][0]

    for key in ("bass", "bass2", "bass3"):
        bass = spec.get(key)
        if not bass:
            continue
        pattern = bass["pattern"]
        step = {"16": 0.25, "4": 1.0}.get(pattern, 0.5)
        for (out, bar, level, first, end) in placed:
            for k in range(int(beats / step)):
                off = k * step
                root = root_at(out, float(int(off)) + (0.5 if off % 1 >= 0.5 else 0))
                if root is None:
                    continue
                p = into_range(root, bass["low"], bass["high"])
                if pattern == "8oct" and k % 2 == 1:
                    p += 12
                vel = 124 if off == 0 else 112 if off == int(off) else 96
                score.add(bass["voice"], out * beats + off, min(step * 0.8, 0.5), p, vel)

    timp = spec.get("timpani")
    if timp:
        for (out, bar, level, first, end) in placed:
            for b in range(beats):
                root = root_at(out, float(b))
                if root is None:
                    continue
                p = into_range(root, 41, 53)
                if end and b == beats - 1:
                    for k in range(8):  # 区切りの前の連打（強めていく）。
                        score.add("timpani", out * beats + b + 0.125 * k, 0.12, p, 80 + 6 * k)
                elif timp["pattern"] == "8" or level >= 3:
                    score.add("timpani", out * beats + b, 0.45, p, 122 if b == 0 else 104)
                    score.add("timpani", out * beats + b + 0.5, 0.45, p, 88)
                elif b == 0 or level >= 2:
                    score.add("timpani", out * beats + b, 0.9, p, 124 if b == 0 else 106)

    kind = spec.get("drums")
    if kind:
        for (out, bar, level, first, end) in placed:
            drum_bar(score, kind, out * beats, beats, level, first, end)

    stabs = spec.get("stabs")
    if stabs:
        for (out, bar, level, first, end) in placed:
            if level < stabs["min_level"] and not first:
                continue
            for off in stabs["rhythm"]:
                if off >= beats:
                    continue
                root, upper = harmony[(out, float(int(off)) + (0.5 if off % 1 else 0))]
                if root is None:
                    continue
                pcs = sorted({into_range(p, 55, 70) for p in upper})
                for voice in stabs["voices"]:
                    if voice in ("trombone", "tuba"):
                        lo = into_range(root, 40, 52) - (12 if voice == "tuba" else 0)
                        tones = [lo, lo + 7]
                    elif voice == "trumpet":
                        tones = [into_range(p, 62, 76) for p in upper[-2:]] if upper else []
                    else:
                        tones = pcs
                    for p in tones:
                        score.add(voice, out * beats + off, 0.38, p, 122 if off == 0 else 110)

    if spec.get("low_brass"):
        # 低い金管: 区切りの頭の小節に、根音をオクターブで 1 拍（打ち込みの土台）。
        for (out, bar, level, first, end) in placed:
            if first or level >= 3:
                root = root_at(out, 0.0)
                if root is not None:
                    p = into_range(root, 36, 48)
                    score.add("tuba", out * beats, 0.9, p, 118)
                    score.add("trombone", out * beats, 0.9, p + 12, 112)

    pad = spec.get("pad")
    if pad:
        for (out, bar, level, first, end) in placed:
            for half in range(0, beats, 2 if beats == 4 else 3):
                root, upper = harmony[(out, float(half))]
                low, high = (55, 72) if pad["voice"] == "choir" else (52, 72)
                for p in sorted({into_range(p, low, high) for p in upper}):
                    score.add(pad["voice"], out * beats + half, (2 if beats == 4 else 3) * 0.95, p, 96)

    power = spec.get("power")
    if power:
        for (out, bar, level, first, end) in placed:
            if level < power["min_level"]:
                continue
            for k in range(beats * 2):
                off = k * 0.5
                root = root_at(out, float(int(off)) + (0.5 if off % 1 else 0))
                if root is None:
                    continue
                p = into_range(root, 40, 52)
                for q in (p, p + 7, p + 12):
                    score.add("power", out * beats + off, 0.35, q, 112 if off == int(off) else 96)

    return score, total_bars * beats, spec["tempo"], beats


def write_midi(score, total_beats, tempo, beats, path):
    mid = mido.MidiFile(type=1, ticks_per_beat=OUT_TPB)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(tempo), time=0))
    meta.append(mido.MetaMessage("time_signature", numerator=beats, denominator=4, time=0))
    # ループの終わりのあとに 2 小節、何も鳴らさない間を置く（書き出しで残響の尾まで録るため。finish.py が頭に重ねる）。
    meta.append(mido.MetaMessage("marker", text="loop_end", time=int(total_beats * OUT_TPB)))
    meta.append(mido.MetaMessage("end_of_track", time=int(2 * beats * OUT_TPB)))
    mid.tracks.append(meta)
    free = [c for c in range(16) if c != DRUM_CH]
    for layer in CHANNELS:
        notes = score.notes.get(layer)
        if not notes:
            continue
        program, volume, pan, reverb = CHANNELS[layer]
        if layer == "drums":
            ch = DRUM_CH
        else:
            if not free:
                raise SystemExit("チャンネルが足りない（15 楽器まで）")
            ch = free.pop(0)
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
    score, total_beats, tempo, beats = arrange(parts, sys.argv[2])
    write_midi(score, total_beats, tempo, beats, sys.argv[3])
    seconds = total_beats * 60.0 / tempo
    with open(sys.argv[3] + ".loop", "w") as f:
        f.write(f"{seconds:.6f}\n")
    print(f"{sys.argv[2]}: ♩={tempo}, {total_beats // beats} 小節, ループ {seconds:.2f} 秒")


if __name__ == "__main__":
    main()
