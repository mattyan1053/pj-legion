"""緩急のある編曲（arrange.py の VERSIONS で "wave" を持つ版）。

前の版（強い所だけを切り出して全部 f）は、主旋律と緩急が消えた。ここでは原曲の流れに沿って、
「落ち着き → 溜め → 盛り上がり」を 1 周に 2 回作る。

- form: (始めの小節, 終わりの小節（含まない）, mode)。mode は区切りの役:
  - calm: 落ち着き。合奏の 8 分の連打と独奏のトリル。弦は弱く長めに、低音は伸ばす、ドラムはハーフタイムで薄く。
  - solo: 独奏の旋律。伴奏はさらに薄い（拍は止めない）。
  - build / mid: 溜め。低音が 8 分、ギターは伸ばす、ドラムはハーフタイム。build は区切りの中で強めていく。
  - peak: 盛り上がり（同音の連打の合奏）。全部の層。低音とハイハットが 16 分、ギターの刻み。
- 主旋律（melody_line）: 拍ごとに、独奏が旋律を弾いていれば独奏、トリルか休みならいちばん上の合奏の声。
  リードがこれをなぞる（calm は伸ばした音で弱く、build は同じ高さ、peak は同じ高さ + 1 オクターブ上）。
  独奏ヴァイオリンは楽譜のまま、どの区切りでも前に出す。足す層（ギター・低音・パッド）は旋律より下の音域に置く。
- 動機（motif_halves）: 盛り上がりの合奏の「16 分 1 つ + 32 分 6 つ + 16 分 4 つ」は、ドラムとギターも同じリズムで打つ。
- 強打（figure）: 区切りの終わりの小節で、ドラム・低音・ギターがそろって打つ型。小節の拍に乗せ、終わりのあとの 1 拍目に
  シンバルを置く（前の版は 4 拍目に強打 + 無音で、拍が 1 つ欠けて聞こえた）。旋律と弦は止めない。拍ごとにハイハットを踏む。
  和音はその小節のまま（調を外さない）。型は場所ごとに、その小節の旋律のリズムに合わせる（FIGURES・BAR_FIGURES）。
- 濁り（dark）: build / mid / peak の頭の 1 拍目に、短 2 度 + 増 4 度のクラスター。その小節の低音の裏を半音上に。
"""
from arrange import (CRASH, CRASH2, HAT, HAT_OPEN, KICK, RIDE, SNARE, TOMS, Score, Source, into_range)

RIM, HAT_PEDAL = 37, 44

# 区切りの役 -> 強さ（始まり, 終わり）。弦と独奏の強さの倍率になる（区切りの中でまっすぐ変える）。
INTENSITY = {"calm": (0.0, 0.25), "solo": (0.1, 0.1), "mid": (0.6, 0.6), "build": (0.45, 0.9), "peak": (1.0, 1.0)}

# 強打の型: 小節の中の (拍, 種類)。q = 4 分の強打、e = 8 分、s = 16 分の連打、p = 弱い 16 分（タム）。
# 型の始まりより後ろは、ふだんの型を止める。最後の強打は、どれも次の小節の 1 拍目（シンバルとキック）。
# 型は場所（元の小節）ごとに、その小節の旋律のリズムに合わせて選ぶ（BAR_FIGURES）。
FIGURES = {
    # 8 分の同音が 4 つずつ（レ♭ → ミ）で上がる小節: 4 分 2 つ、そのあと旋律と同じ 8 分で 4 つ。
    "eighths": [(0, "q"), (1, "q"), (2, "e"), (2.5, "e"), (3, "e"), (3.5, "e")],
    # 拍ごとに 1 段ずつ下りる 16 分の連打の小節: 拍の頭を 4 つ打ち、最後の拍は旋律と同じ 16 分で。
    "steps": [(0, "q"), (1, "q"), (2, "q"), (3, "s"), (3.25, "s"), (3.5, "s"), (3.75, "s")],
    # 3 拍目で合奏が止まり、独奏の走句だけが次へ上がっていく小節: 3 拍目に 1 つ打って空け、終わりにタムの弱い 2 つ。
    "cadence": [(2, "q"), (3.5, "p"), (3.75, "p")],
    # 落ち着き・独奏の終わり（8 分の連打や走句の上）: タムで弱く、8 分 2 つと 16 分 2 つ。
    "soft": [(2, "p8"), (3, "p8"), (3.5, "p"), (3.75, "p")],
    # 合奏の 16 分の連打で終わる小節: 4 拍目だけ 16 分で。
    "tail": [(3, "s"), (3.25, "s"), (3.5, "s"), (3.75, "s")],
}
# 元の小節 -> 型。ここに無い区切りの終わりは、落ち着き・独奏なら soft、ほかは tail。
# 盛り上がりの終わりの 61 小節（ループの終わり）は、小節まるごと動機（下の MOTIF）なので、型を足さない。
BAR_FIGURES = {18: "eighths", 54: "steps", 25: "cadence", 61: None, 17: None, 14: None}


def figure_for(bar, mode):
    if bar in BAR_FIGURES:
        return BAR_FIGURES[bar]
    return "soft" if mode in ("calm", "solo") else "tail"


def motif_halves(line):
    """小節の主旋律の中で、合奏の動機「タッ タラララララ タンッタンッタンッタンッ」（16 分 1 つ、32 分 6 つ、16 分 4 つ。2 拍）が
    始まる拍（0 か 2）の組。楽譜の書き込みは「Correre, e batter li piedi per il freddo」（寒さに走り、足を踏み鳴らす）。"""
    found = set()
    for h in (0, 2):
        offs = sorted(round(o - h, 3) for (o, l, n) in line if h <= o < h + 2)
        if offs == [0, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1, 1.25, 1.5, 1.75]:
            found.add(h)
    return found


def melody_line(src, bar):
    """小節の主旋律: [(小節の中の拍, 長さ, 高さ)]。拍ごとに、独奏（トリルでなければ）か、いちばん上の合奏の声。"""
    out = []
    solo = src.bar_notes("solo", bar)
    for b in range(src.beats):
        mine = [(o, l, n) for (o, l, n) in solo if b <= o < b + 1]
        if 0 < len(mine) <= 8:
            out += mine
            continue
        best = []
        for part in ("violinone", "violintwo", "viola", "cello"):
            notes = [(o, l, n) for (o, l, n) in src.bar_notes(part, bar) if b <= o < b + 1]
            if notes and (not best or max(n for (_, _, n) in notes) > max(n for (_, _, n) in best)):
                best = notes
        out += best
    return out


def arrange_wave(parts, spec, beats):
    src = Source(parts, beats)
    score = Score()
    peak_drums = spec.get("peak_drums", "full")

    placed = []  # (出す小節, 元の小節, mode, 強さ 0〜1, 区切りの頭か, 区切りの終わりか, 区切りの番号)
    sections = []  # (始めの出す小節, 終わりの出す小節, mode, 元の小節の範囲)
    at = 0
    for index, (start, end, mode) in enumerate(spec["form"]):
        lo, hi = INTENSITY[mode]
        n = end - start
        for i, bar in enumerate(range(start, end)):
            level = lo + (hi - lo) * (i / (n - 1) if n > 1 else 1.0)
            placed.append((at, bar, mode, level, bar == start, bar == end - 1, index))
            at += 1
        sections.append((at - n, at, mode, (start, end)))
    total_bars = at

    def gain(level, floor=0.78):
        """強さ -> 音の強さ（velocity）の倍率。"""
        return floor + (1.0 - floor) * level

    # 強打を置く小節: 出す小節 -> 型。
    figures = {}
    for (out, bar, mode, level, first, end, index) in placed:
        if end:
            name = figure_for(bar, mode)
            if name:
                figures[out] = name
    accents = {(out + 1) % total_bars for (out, bar, mode, level, first, end, index) in placed if end and mode != "solo"}
    accents |= {(out + 1) % total_bars for out in figures}  # 区切りの終わりのあとの 1 拍目
    # 動機（盛り上がりの中）: 出す小節 -> 始まる拍の組。そこは、ドラムとギターが旋律と同じリズムで打つ。
    motifs = {out: motif_halves(melody_line(src, bar)) for (out, bar, mode, *_r) in placed if mode == "peak"}

    def groove(out, off):
        """ふだんのドラムとギターの型を鳴らしてよいか（強打の型にも、動機にも取られていない）。"""
        return free(out, off) and (2 if off >= 2 else 0) not in motifs.get(out, ())

    def free(out, off):
        """その拍が、強打の型に取られていないか（ふだんの型を鳴らしてよいか）。"""
        name = figures.get(out)
        return not name or off < FIGURES[name][0][0] - 1e-6

    # 拍ごとの和声（8 分の細かさ）。休みの拍は前の和声を引き継ぐ。
    harmony = {}
    last = (None, [])
    for (out, bar, *_rest) in placed:
        for k in range(beats * 2):
            root, upper = src.harmony(bar * beats + k * 0.5)
            if root is None:
                root, upper = last
            else:
                last = (root, upper)
            harmony[(out, k * 0.5)] = (root, upper)
    first_root = next(r for (r, _) in harmony.values() if r is not None)

    def root_at(out, off):
        root = harmony[(out, int(off * 2) / 2.0)][0]
        return first_root if root is None else root

    def chord_at(out, off):
        return harmony[(out, int(off * 2) / 2.0)][1]

    # --- 楽譜の声（弦と独奏） ---
    def strings(part, layer, vel, modes=None):
        for (out, bar, mode, level, first, end, _) in placed:
            if modes and mode not in modes:
                continue
            base = out * beats
            quiet = mode in ("calm", "solo")
            g = gain(level)
            for (off, length, n) in src.bar_notes(part, bar):
                accent = 12 if abs(off - round(off)) < 1e-6 else 0
                if quiet:
                    # 落ち着き: 楽譜の長さに近く（切らない）。
                    score.add(layer, base + off, min(length * 0.92, 1.9), n, (vel + accent) * g)
                elif length > 0.75:
                    k = 0
                    while k * 0.5 < length - 1e-6:
                        o = off + k * 0.5
                        a = 12 if abs(o - round(o)) < 1e-6 else 0
                        score.add(layer, base + o, 0.35, n, (vel + a) * g)
                        k += 1
                else:
                    score.add(layer, base + off, min(length * 0.8, 0.4), n, (vel + accent) * g)

    strings("violinone", "violin1", 96)
    strings("violinone", "violin1b", 84, modes=("peak",))
    strings("violintwo", "violin2", 92)
    strings("viola", "viola", 90)
    strings("cello", "cello", 100)

    for (out, bar, mode, level, first, end, _) in placed:
        notes = src.bar_notes("solo", bar)
        for b in range(beats):
            mine = [(o, l, n) for (o, l, n) in notes if b <= o < b + 1]
            trill = len(mine) > 8
            for (off, length, n) in mine:
                vel = 84 * gain(level, 0.85) if trill else (112 + (10 if off == int(off) else 0)) * gain(level, 0.93)
                score.add("solo", out * beats + off, min(length, 1.0) * 0.95, n, vel)

    # --- リード: 主旋律をなぞる ---
    held = None  # calm で伸ばしている音 [始まり, 終わり, 高さ]
    for (out, bar, mode, level, first, end, _) in placed:
        base = out * beats
        line = melody_line(src, bar)
        if mode == "calm":
            for (off, length, n) in line:
                if held and held[2] == n and abs(held[1] - (base + off)) < 0.51:
                    held[1] = base + off + length
                else:
                    if held:
                        score.add("saw_lead", held[0], held[1] - held[0], held[2], 92)
                    held = [base + off, base + off + length, n]
            continue
        if held:
            score.add("saw_lead", held[0], held[1] - held[0], held[2], 92)
            held = None
        if mode == "solo":
            continue
        for (off, length, n) in line:
            vel = (104 + (14 if off == int(off) else 0)) * gain(level, 0.8)
            score.add("saw_lead", base + off, min(length * 0.85, 0.45), n, vel)
            if mode == "peak":
                score.add("saw_lead", base + off, min(length * 0.85, 0.45), n + 12, vel - 16)
    if held:
        score.add("saw_lead", held[0], held[1] - held[0], held[2], 92)

    # --- 低音 ---
    hold_bass = None
    for (out, bar, mode, level, first, end, _) in placed:
        base = out * beats
        dark_bar = spec.get("dark") and first and mode in ("build", "mid", "peak")
        if mode in ("calm", "solo"):
            for b in range(beats):
                if not free(out, b):
                    break
                p = into_range(root_at(out, b), 28, 40)
                if hold_bass and hold_bass[2] == p and b not in (0, 2):
                    hold_bass[1] = base + b + 1
                else:
                    if hold_bass:
                        score.add("synth_bass", hold_bass[0], hold_bass[1] - hold_bass[0] - 0.05, hold_bass[2], 110)
                    hold_bass = [base + b, base + b + 1, p]
            continue
        if hold_bass:
            score.add("synth_bass", hold_bass[0], hold_bass[1] - hold_bass[0] - 0.05, hold_bass[2], 110)
            hold_bass = None
        step = 0.25 if mode == "peak" else 0.5
        for k in range(int(beats / step)):
            off = k * step
            if not free(out, off):
                break
            p = into_range(root_at(out, off), 28, 40)
            offbeat = abs(off % 1 - 0.5) < 1e-6
            if dark_bar and offbeat:
                p += 1
            elif mode == "peak" and offbeat:
                p += 12
            vel = (124 if off == 0 else 114 if off == int(off) else 98) * gain(level, 0.8)
            score.add("synth_bass", base + off, step * 0.8, p, vel)
            if mode == "peak" and off % 0.5 == 0:
                score.add("finger_bass", base + off, 0.4, into_range(root_at(out, off), 28, 40), vel)
    if hold_bass:
        score.add("synth_bass", hold_bass[0], hold_bass[1] - hold_bass[0] - 0.05, hold_bass[2], 110)

    # --- 歪んだギター（根音と 5 度。旋律より下） ---
    for (out, bar, mode, level, first, end, _) in placed:
        base = out * beats
        if mode in ("build", "mid"):
            for half in range(0, beats, 2):
                if not free(out, half):
                    break
                p = into_range(root_at(out, half), 40, 52)
                length = 1.9 if free(out, half + 1.9) else 0.9
                for q in (p, p + 7, p + 12):
                    score.add("power", base + half, length, q, 100 * gain(level, 0.75))
        elif mode == "peak":
            for b in range(beats):
                for (o, ln, vel) in ((0, 0.4, 114), (0.5, 0.2, 98), (0.75, 0.2, 98)):
                    off = b + o
                    if not groove(out, off):
                        break
                    p = into_range(root_at(out, off), 40, 52)
                    for q in (p, p + 7, p + 12):
                        score.add("power", base + off, ln, q, vel)

    # --- パッド（和音の持続。弱く） ---
    for (out, bar, mode, level, first, end, _) in placed:
        for half in range(0, beats, 2):
            tones = sorted({into_range(p, 52, 67) for p in chord_at(out, half)})
            for p in tones:
                score.add("warm_pad", out * beats + half, 1.9, p, 76 + 12 * level)

    # --- ドラム ---
    def drum(out, off, key, vel, force=False):
        if force or (groove(out, off) if placed[out][2] == "peak" else free(out, off)):
            score.add("drums", out * beats + off, 0.2, key, vel)

    for (out, bar, mode, level, first, end, index) in placed:
        if out in accents:
            drum(out, 0, CRASH, 118, True)
            drum(out, 0, KICK, 120, True)
        if mode == "calm":
            drum(out, 0, KICK, 100)
            drum(out, 2.5, KICK, 78)
            if level > 0.12:
                drum(out, 1.5, KICK, 80)
            drum(out, 2, RIM if level <= 0.12 else SNARE, 86)
            for k in range(8):
                drum(out, k * 0.5, HAT, 62 if k % 2 == 0 else 46)
        elif mode == "solo":
            drum(out, 0, KICK, 98)
            drum(out, 2, RIM, 80)
            drum(out, 2.5, KICK, 70)
            for b in range(beats):
                drum(out, b, HAT_PEDAL, 64)
                drum(out, b + 0.5, HAT, 40)
        elif mode in ("build", "mid"):
            if first:
                drum(out, 0, CRASH2, 108)
            for (off, vel) in ((0, 114), (1.5, 100), (2.5, 106)):
                drum(out, off, KICK, vel)
            drum(out, 2, SNARE, 108 + 14 * level)
            for k in range(8):
                drum(out, k * 0.5, HAT_OPEN if k == 7 else HAT, (86 if k % 2 == 0 else 68) * gain(level, 0.8))
            if level > 0.7:
                for off in (3.5, 3.75):
                    drum(out, off, SNARE, 84)
        elif mode == "peak":
            sec_start = sections[index][0]
            if first or (out - sec_start) % 4 == 0:
                drum(out, 0, CRASH, 124 if first else 104)
                if first:
                    drum(out, 0, CRASH2, 112)
            if peak_drums == "half":
                for (off, vel) in ((0, 127), (0.5, 100), (0.75, 106), (1.5, 112), (2.5, 108), (3, 114), (3.25, 100), (3.75, 106)):
                    drum(out, off, KICK, vel)
                drum(out, 2, SNARE, 127)
                for k in range(16):
                    drum(out, k * 0.25, HAT, (90, 58, 76, 58)[k % 4])
                    if k % 4 == 0:
                        drum(out, k * 0.25, RIDE, 100)
            else:
                for (off, vel) in ((0, 127), (0.75, 104), (1.5, 112), (2, 122), (2.75, 104), (3.5, 110)):
                    drum(out, off, KICK, vel)
                drum(out, 1, SNARE, 124)
                drum(out, 3, SNARE, 124)
                for k in range(16):
                    drum(out, k * 0.25, HAT, (94, 60, 78, 60)[k % 4])

    # --- 動機: 盛り上がりの「タッ タラララララ タンッタンッタンッタンッ」を、ドラム・ギターが旋律と同じリズムで打つ ---
    for out, halves in motifs.items():
        base = out * beats
        for h in sorted(halves):
            if not free(out, h):
                continue
            drum(out, h, KICK, 124, True)
            drum(out, h, SNARE, 112, True)
            drum(out, h, HAT_PEDAL, 84, True)
            drum(out, h + 1, HAT_PEDAL, 84, True)
            for k in range(6):  # 32 分 6 つ: スネアを弱くから強めていく。
                drum(out, h + 0.25 + 0.125 * k, SNARE, 66 + 7 * k, True)
            drum(out, h + 0.5, KICK, 104, True)
            p = into_range(root_at(out, h), 40, 52)
            for q in (p, p + 7, p + 12):
                score.add("power", base + h, 0.2, q, 112)
                score.add("power", base + h + 0.25, 0.7, q, 104)
            for k in range(4):  # 16 分 4 つ: そろって強く。
                off = h + 1 + 0.25 * k
                drum(out, off, SNARE, 122, True)
                drum(out, off, KICK, 118, True)
                p = into_range(root_at(out, off), 40, 52)
                for q in (p, p + 7, p + 12):
                    score.add("power", base + off, 0.2, q, 118)
            for p in sorted({into_range(p, 55, 70) for p in chord_at(out, h + 1)}):
                score.add("brass", base + h + 1, 0.2, p, 100)

    # --- 強打（区切りの終わり） ---
    for out, name in figures.items():
        fig = FIGURES[name]
        rolls = [off for (off, kind) in fig if kind == "s"]
        base = out * beats
        for b in range(beats):
            if b >= fig[0][0] - 1e-6:
                drum(out, b, HAT_PEDAL, 84, True)
        for (off, kind) in fig:
            soft = kind in ("p", "p8")
            if kind == "s":
                i = rolls.index(off)
                vel = 100 + 24 * (i + 1) / len(rolls)
                drum(out, off, SNARE if i < len(rolls) / 2 else TOMS[2 + i], vel, True)
                if off % 0.5 == 0:
                    drum(out, off, KICK, vel, True)
                length = 0.2
            elif soft:
                vel = 88 if kind == "p8" else 94
                drum(out, off, TOMS[3 if kind == "p8" else 4], vel, True)
                length = 0.3 if kind == "p8" else 0.2
            else:
                vel = 124 if kind == "q" else 114
                drum(out, off, SNARE, vel, True)
                drum(out, off, KICK, vel, True)
                if kind == "q":
                    drum(out, off, CRASH2, 110, True)
                length = 0.45 if kind == "q" else 0.3
            root = root_at(out, off)
            score.add("synth_bass", base + off, length, into_range(root, 28, 40), vel)
            if not soft:
                p = into_range(root, 40, 52)
                for q in (p, p + 7, p + 12):
                    score.add("power", base + off, length, q, vel - 8)
                if kind == "q":
                    for p in sorted({into_range(p, 55, 70) for p in chord_at(out, off)}):
                        score.add("brass", base + off, 0.4, p, 112)

    # --- 濁り ---
    if spec.get("dark"):
        for (out, bar, mode, level, first, end, _) in placed:
            if not first or mode not in ("build", "mid", "peak"):
                continue
            root = root_at(out, 0)
            low = into_range(root, 48, 59)
            for p in (low, low + 1, low + 6):
                score.add("brass", out * beats, 0.38, p, 118)
            high = into_range(root, 72, 83)
            for v in ("violin1", "violin2"):
                score.add(v, out * beats, 0.3, high + 1, 112)

    return score, total_bars * beats, sections


