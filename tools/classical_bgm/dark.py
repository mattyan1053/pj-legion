"""暗く重い編曲（arrange.py の VERSIONS で "dark" を持つ版。暗重・暗中・暗電）。

緩急つきの版（swell.py。電重など）は、主旋律と緩急は戻ったが「軽く・明るく・安っぽく」なった（Issue #46 の 11/28 の 3 回目）。
層ごとに測ると、2 kHz 以上の力の 4 割がノコギリ波のリード（旋律 + 1 オクターブ上）、2 割が独奏ヴァイオリン（音量 127）だった。
ここでは、人間が良いと言った重（圧）と電2（戦闘曲らしさ）を土台に、次の 3 つを直す。

1. 伸ばす音に揺れ（Score.shape）: 0.3 秒より長い音に、遅れて掛かるビブラート（ピッチベンドの細かい揺れ）と、
   強さの動き（エクスプレッション CC11 で膨らんでしぼむ）。リードは 2 つの音色を数セントずらして重ねる（うなり）。
   低音とギターと弦は伸ばさず、刻み直す。パッドは合唱（音色そのものが揺れている）を低い所で。
   spec["hold"] が False の版（暗電）は、リードも伸ばさずに旋律のリズムで打つ（伸ばして揺らすのと、どちらが良いかを比べる）。
2. 暗く・重く: リードは旋律の 1 オクターブ下（シンセブラス + ノコギリ波。上のオクターブは重ねない）。独奏の音量を下げる。
   第 1 ヴァイオリンの重ねは 1 オクターブ下。ハイハットは 8 分で弱く、16 分のハイハットとライドは無し、シンバルは区切りの頭だけ。
   低音はシンセベースの刻み + 太いシンセベース（重と同じ音色）。大太鼓を重ねる。和音（パッド・ギター）は根音・5 度・短 3 度だけ。
   金管は低い所（トロンボーン・チューバ）の短い打ち込みだけ。区切りの頭の濁り（短 2 度 + 増 4 度）は低い所に置く。
3. 動機「タッ タラララララ タンッ×4」（16 分 1 つ + 32 分 6 つ + 16 分 4 つ）を、区切って重く打つ（strike_motif）:
   全部の層が同じリズムのユニゾンで、1 音ずつ短く切る（音の間に隙間）。リードは 32 分を弾かない。
   32 分 6 つは低い弦・ギターの低い弦・低音・フロアタムとキックで、だんだん強く。「タンッ×4」は全員でいちばん強く。
   spec["motif"]: "32" = 32 分のまま（遅い版）、"16" = 32 分 6 つを 16 分 3 つに間引く（速い版）、
   "split" = 低い層は 32 分のまま、高い層（ヴァイオリン・独奏・リード）は 16 分 3 つ。

区切りの役（form の 3 つ目）: low（落ち着き。ただし低音の 8 分と拍は残す）/ solo（独奏の走句）/ build（溜め）/ mid / peak。
強打の型（区切りの終わり）は swell.py と同じ（拍に乗せ、無音を作らない）。
"""
import math

from arrange import CRASH, HAT, KICK, BASS_DRUM, SNARE, TOMS, Score, Source, into_range
from swell import FIGURES, figure_for, motif_halves

RIM, HAT_PEDAL, FLOOR_TOM, LOW_TOM = 37, 44, 41, 43

# 区切りの役 -> 強さ（始まり, 終わり）。落ち着く所でも圧を抜かない（swell.py より底が高い）。
INTENSITY = {"low": (0.8, 0.9), "solo": (0.85, 0.85), "mid": (0.9, 0.9), "build": (0.8, 1.0), "peak": (1.0, 1.0)}

HIGH_PARTS = ("solo", "violinone", "violintwo")


def thin(notes, halves):
    """動機の 32 分 6 つを、16 分 3 つに間引く（1・3・5 つ目を残し、長さを 16 分に）。"""
    out = []
    for (off, length, n) in notes:
        h = 2 if off >= 2 else 0
        rel = round(off - h, 3)
        if h in halves and 0.25 <= rel < 1.0 and length <= 0.13:
            if round(rel * 8) % 2 == 0:
                out.append((off, 0.25, n))
        else:
            out.append((off, length, n))
    return out


def lead_line(src, bar):
    """リードがなぞる線: 拍ごとに、独奏が旋律（トリルでない）を弾いていれば独奏、でなければ第 1 ヴァイオリン。"""
    out = []
    solo = src.bar_notes("solo", bar)
    tutti = src.bar_notes("violinone", bar)
    for b in range(src.beats):
        mine = [(o, l, n) for (o, l, n) in solo if b <= o < b + 1]
        if not 0 < len(mine) <= 4:
            mine = [(o, l, n) for (o, l, n) in tutti if b <= o < b + 1] or (mine if len(mine) <= 8 else [])
        # 重音は上の音だけ。
        tops = {}
        for (o, l, n) in mine:
            if o not in tops or n > tops[o][2]:
                tops[o] = (o, l, n)
        out += [tops[o] for o in sorted(tops)]
    return out


def arrange_dark(parts, spec, beats):
    src = Source(parts, beats)
    score = Score()
    motif_mode = spec.get("motif", "32")
    snare_beats = spec.get("snare", (1, 3))  # 盛り上がりのスネアの拍。遅い版は 2・4 拍、速い版は 3 拍（ハーフタイム）。

    placed = []  # (出す小節, 元の小節, mode, 強さ 0〜1, 区切りの頭か, 区切りの終わりか, 区切りの番号)
    sections = []
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

    def gain(level, floor=0.8):
        return floor + (1.0 - floor) * level

    figures = {}
    for (out, bar, mode, level, first, end, index) in placed:
        if end:
            name = figure_for(bar, "calm" if mode == "low" else mode)
            if name:
                figures[out] = name
    accents = {(out + 1) % total_bars for (out, bar, mode, level, first, end, index) in placed if end}
    # 動機は、どの役の区切りでも拾う（第 1 ヴァイオリンのリズムで見分ける）。
    motifs = {out: motif_halves(src.bar_notes("violinone", bar)) for (out, bar, *_r) in placed}
    motifs = {out: h for out, h in motifs.items() if h}

    def free(out, off):
        name = figures.get(out)
        return not name or off < FIGURES[name][0][0] - 1e-6

    def groove(out, off):
        return free(out, off) and (2 if off >= 2 else 0) not in motifs.get(out, ())

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

    def dark_tones(out, off, low, high):
        """和音を暗く積む: 根音と 5 度、短 3 度があればそれも（長 3 度は入れない）。"""
        root = root_at(out, off)
        pcs = {p % 12 for p in harmony[(out, int(off * 2) / 2.0)][1]}
        tones = [root, root + 7] + ([root + 3] if (root + 3) % 12 in pcs else [])
        return sorted({into_range(p, low, high) for p in tones})

    # --- 楽譜の声（弦と独奏）。伸ばす音は刻み直す（トレモロ）。動機の所は strike_motif が打つ ---
    def in_motif(out, off):
        return (2 if off >= 2 else 0) in motifs.get(out, ())

    def strings(part, layer, vel, shift=0, modes=None):
        for (out, bar, mode, level, first, end, _) in placed:
            if modes and mode not in modes:
                continue
            base = out * beats
            g = gain(level)
            grid = 0.5 if mode in ("low", "solo") else 0.25
            for (off, length, n) in src.bar_notes(part, bar):
                if in_motif(out, off):
                    continue
                accent = 12 if abs(off - round(off)) < 1e-6 else 0
                if length > grid * 1.5:
                    k = 0
                    while k * grid < length - 1e-6:
                        o = off + k * grid
                        a = 12 if abs(o - round(o)) < 1e-6 else 0
                        score.add(layer, base + o, grid * 0.7, n + shift, (vel + a) * g)
                        k += 1
                else:
                    score.add(layer, base + off, min(length * 0.8, 0.4), n + shift, (vel + accent) * g)

    strings("violinone", "violin1", 94)
    strings("violinone", "low_strings", 92, shift=-12, modes=("mid", "build", "peak"))
    strings("violintwo", "violin2", 90)
    strings("viola", "viola", 94)
    strings("cello", "cello", 104)

    for (out, bar, mode, level, first, end, _) in placed:
        notes = src.bar_notes("solo", bar)
        for b in range(beats):
            mine = [(o, l, n) for (o, l, n) in notes if b <= o < b + 1 and not in_motif(out, o)]
            trill = len(mine) > 8
            for (off, length, n) in mine:
                vel = 80 * gain(level, 0.85) if trill else (106 + (10 if off == int(off) else 0)) * gain(level, 0.9)
                score.add("solo", out * beats + off, min(length, 2.0) * 0.95, n, vel)

    # --- リード: 主旋律を 1 オクターブ下でなぞる（シンセブラス + 少しずらしたノコギリ波）。同じ高さの連打はつないで伸ばす ---
    def lead(start, length, pitch, vel):
        p = pitch - 12
        while p > 79:  # 高い所は、もう 1 オクターブ下げる。
            p -= 12
        score.add("lead", start, length, p, vel)
        score.add("lead2", start, length, p, vel - 14)

    hold = spec.get("hold", True)  # False なら、リードも伸ばさず、旋律のリズムのまま短く打つ（電2 と同じ）。
    held = None

    def flush():
        nonlocal held
        if held:
            lead(held[0], held[1] - held[0], held[2], held[3])
            held = None

    for (out, bar, mode, level, first, end, _) in placed:
        base = out * beats
        if mode == "solo":
            flush()
            continue
        for (off, length, n) in lead_line(src, bar):
            if in_motif(out, off):
                flush()
                continue
            if hold and mode in ("low", "build", "mid") and length <= 0.5:
                # 連打は伸ばした音に（リードは刻まない。刻みは弦とギターが受け持つ）。小節をまたいだら弾き直す。
                if held and held[2] == n and abs(held[1] - (base + off)) < 0.51 and base + off - held[0] < beats:
                    held[1] = base + off + length
                else:
                    flush()
                    held = [base + off, base + off + length, n, (92 + 14 * level)]
            else:
                flush()
                vel = (102 + (14 if off == int(off) else 0)) * gain(level)
                lead(base + off, length * 0.9 if length > 0.5 else min(length * 0.85, 0.45), n, vel)
    flush()

    # --- 低音: 伸ばさない。シンセベースの刻み + 太いシンセベース（拍ごと・8 分） ---
    for (out, bar, mode, level, first, end, _) in placed:
        base = out * beats
        dark_bar = first and mode in ("build", "mid", "peak")
        step = 0.25 if mode == "peak" else 0.5
        g = gain(level)
        for k in range(int(beats / step)):
            off = k * step
            if not groove(out, off):
                continue
            p = into_range(root_at(out, off), 28, 39)
            offbeat = abs(off % 1 - 0.5) < 1e-6
            q = p + 1 if dark_bar and offbeat else p + 12 if mode in ("peak", "mid") and offbeat else p
            vel = (124 if off == 0 else 114 if off == int(off) else 100) * (g if mode == "peak" else 1.0) * (0.92 if mode == "peak" else 1.0)
            score.add("synth_bass", base + off, step * 0.75, q, vel)
            if off % 0.5 == 0:
                score.add("sub_bass", base + off, 0.4, p, vel)

    # --- 歪んだギター: 低い弦の刻み（根音と 5 度。盛り上がりはオクターブも）。伸ばさない ---
    for (out, bar, mode, level, first, end, _) in placed:
        base = out * beats
        g = gain(level, 0.7)
        if mode == "peak":
            pattern = [(b + o, ln, v) for b in range(beats) for (o, ln, v) in ((0, 0.4, 108), (0.5, 0.18, 92), (0.75, 0.18, 92))]
        elif mode in ("mid", "build"):
            pattern = [(k * 0.5, 0.3, 110 if k % 2 == 0 else 94) for k in range(beats * 2)]
        elif mode == "low":
            pattern = [(k * 0.5, 0.25, 112 if k % 2 == 0 else 96) for k in range(beats * 2)]
        else:
            pattern = [(k * 0.5, 0.25, 112 if k % 2 == 0 else 96) for k in range(beats * 2)]
        for (off, ln, vel) in pattern:
            if not groove(out, off):
                continue
            p = into_range(root_at(out, off), 40, 51)
            tones = (p, p + 7, p + 12) if mode == "peak" else (p, p + 7)
            for q in tones:
                score.add("power", base + off, ln, q, vel * g)

    # --- 低い弦の刻み（落ち着き・独奏の所の圧。根音と 5 度を 8 分、独奏の所は 16 分で） ---
    for (out, bar, mode, level, first, end, _) in placed:
        if mode not in ("low", "solo"):
            continue
        step = 0.25 if mode == "solo" else 0.5
        for k in range(int(beats / step)):
            off = k * step
            if not groove(out, off):
                continue
            p = into_range(root_at(out, off), 41, 52)
            vel = (112 if off == int(off) else 92) if mode == "low" else (98 if off == int(off) else 80)
            for q in (p, p + 7):
                score.add("low_strings", out * beats + off, step * 0.7, q, vel)

    # --- パッド: 合唱（低い所）と暖かいパッド。2 拍ごとに鳴らし直し、強さを膨らませてしぼませる（Score.shape） ---
    for (out, bar, mode, level, first, end, _) in placed:
        for half in range(0, beats, 2):
            if in_motif(out, half):
                continue
            for p in dark_tones(out, half, 48, 60):
                score.add("choir", out * beats + half, 1.95, p, 84 + 16 * level)
            score.add("warm_pad", out * beats + half, 1.95, into_range(root_at(out, half), 41, 52), 80 + 14 * level)

    # --- ドラム ---
    def drum(out, off, key, vel, force=False):
        if force or groove(out, off):
            score.add("drums", out * beats + off, 0.2, key, vel)

    def kick(out, off, vel, force=False):
        drum(out, off, KICK, vel, force)
        drum(out, off, BASS_DRUM, vel - 8, force)

    for (out, bar, mode, level, first, end, index) in placed:
        if out in accents:
            drum(out, 0, CRASH, 112, True)
            kick(out, 0, 122, True)
        if mode in ("low", "solo"):
            for (off, vel) in ((0, 124), (0.5, 96), (1, 104), (1.5, 110), (2.5, 112), (3, 104), (3.5, 96)):
                kick(out, off, vel)
            drum(out, 2, SNARE, 120)
            drum(out, 2, LOW_TOM, 100)
            for b in range(beats):
                drum(out, b, HAT_PEDAL, 60)
            if mode == "low" and level > 0.5:
                drum(out, 3.5, FLOOR_TOM, 86)
                drum(out, 3.75, FLOOR_TOM, 92)
        elif mode in ("build", "mid"):
            for (off, vel) in ((0, 120), (0.75, 96), (1.5, 108), (2.5, 110), (3.25, 96)):
                kick(out, off, vel)
            drum(out, 2, SNARE, 112 + 12 * level)
            for k in range(8):
                drum(out, k * 0.5, HAT, (70 if k % 2 == 0 else 50) * gain(level))
            if level > 0.8:
                for (off, key) in ((3.5, LOW_TOM), (3.75, FLOOR_TOM)):
                    drum(out, off, key, 100)
        elif mode == "peak":
            for k in range(16):  # 16 分のキック（拍の頭を強く。大太鼓は拍の頭だけ重ねる）。
                drum(out, k * 0.25, KICK, (116, 80, 96, 80)[k % 4])
                if k % 4 == 0:
                    drum(out, k * 0.25, BASS_DRUM, 100)
            for b in snare_beats:
                drum(out, b, SNARE, 127)
                drum(out, b, LOW_TOM, 100)
            for k in range(8):
                drum(out, k * 0.5, HAT, 64 if k % 2 == 0 else 46)

    # --- 動機: 全部の層が同じリズムで、1 音ずつ区切って打つ ---
    def strike_motif(out, bar, h, level):
        base = out * beats
        g = gain(level, 0.9)
        keep32 = motif_mode in ("32", "split")
        root = root_at(out, h + 1)
        low_root = into_range(root, 28, 39)
        gtr = into_range(root, 40, 51)
        # 楽譜の声: その半分の音を、短く切って打つ。伸ばしている声（チェロなど）も同じリズムで打ち直す。
        rhythm = [0.0] + ([0.25 + 0.125 * k for k in range(6)] if keep32 else [0.25, 0.5, 0.75]) + [1.0, 1.25, 1.5, 1.75]
        thin_rhythm = [0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75]

        def weight(rel):
            """(強さ, 長さ（拍）)。頭の 16 分は強く、走る音はだんだん強く、「タンッ×4」はいちばん強く。"""
            if rel >= 1.0:
                return 127, 0.13
            if rel == 0.0:
                return 120, 0.14
            return 92 + 24 * (rel - 0.25) / 0.75, (0.07 if keep32 else 0.13)

        for part, layer, shift in (("solo", "solo", 0), ("violinone", "violin1", 0), ("violinone", "low_strings", -12),
                                   ("violintwo", "violin2", 0), ("viola", "viola", 0), ("cello", "cello", 0)):
            notes = [(o - h, l, n) for (o, l, n) in src.bar_notes(part, bar) if h <= o < h + 2]
            if not notes:
                continue
            high = part in HIGH_PARTS and layer != "low_strings"
            steps = thin_rhythm if (motif_mode == "16" or (motif_mode == "split" and high)) else rhythm
            for rel in steps:
                # その時刻に鳴っている（はずの）高さ: 直前に始まった音。重音は全部。
                starts = sorted({o for (o, l, n) in notes if o <= rel + 1e-6})
                if not starts:
                    continue
                vel, ln = weight(rel)
                if steps is thin_rhythm and 0 < rel < 1:
                    ln = 0.13
                for (o, l, n) in notes:
                    if o == starts[-1]:
                        score.add(layer, base + h + rel, ln, n + shift, (vel - (10 if layer == "solo" else 0)) * g)
        # リード: 32 分は弾かない（頭 + 16 分 3 つ + タンッ×4）。1 オクターブ下。
        line = [(o - h, n) for (o, l, n) in lead_line(src, bar) if h <= o < h + 2]
        for rel in thin_rhythm:
            cur = [n for (o, n) in line if o <= rel + 1e-6]
            if cur:
                vel, _ = weight(rel)
                lead(base + h + rel, 0.13, cur[-1], vel * g)
        # 低音・ギター・ドラム。
        for rel in rhythm:
            vel, ln = weight(rel)
            t = base + h + rel
            score.add("synth_bass", t, ln, low_root, vel * g)
            if rel >= 1.0 or rel == 0.0:
                score.add("sub_bass", t, 0.2, low_root, vel * g)
                for q in (gtr, gtr + 7, gtr + 12):
                    score.add("power", t, 0.14, q, vel * g)
                kick(out, h + rel, 127, True)
                drum(out, h + rel, SNARE, 127 if rel >= 1.0 else 116, True)
                if rel >= 1.0:
                    drum(out, h + rel, FLOOR_TOM, 118, True)
                    for p in (into_range(root, 36, 47), into_range(root, 36, 47) + 7, into_range(root, 48, 59)):
                        score.add("trombone", t, 0.15, p, 120 * g)
                    score.add("tuba", t, 0.15, into_range(root, 29, 40), 120 * g)
            else:
                # 走る音: ギターの低い弦 1 本、フロアタムとキック。
                score.add("power", t, ln, gtr, vel * g)
                score.add("power", t, ln, gtr + 7, (vel - 10) * g)
                kick(out, h + rel, vel, True)
                drum(out, h + rel, FLOOR_TOM if rel < 0.6 else LOW_TOM, vel, True)
        drum(out, h, HAT_PEDAL, 80, True)

    for out, halves in motifs.items():
        (_, bar, mode, level, *_r) = placed[out]
        for h in sorted(halves):
            if free(out, h):
                strike_motif(out, bar, h, level)

    # --- 強打（区切りの終わり。型は swell.py と同じ） ---
    for out, name in figures.items():
        fig = FIGURES[name]
        rolls = [off for (off, kind) in fig if kind == "s"]
        base = out * beats
        for b in range(beats):
            if b >= fig[0][0] - 1e-6:
                drum(out, b, HAT_PEDAL, 80, True)
        for (off, kind) in fig:
            soft = kind in ("p", "p8")
            if kind == "s":
                i = rolls.index(off)
                vel = 100 + 24 * (i + 1) / len(rolls)
                drum(out, off, SNARE if i < len(rolls) / 2 else TOMS[2 + i], vel, True)
                kick(out, off, vel, True)
                length = 0.18
            elif soft:
                vel = 92 if kind == "p8" else 98
                drum(out, off, LOW_TOM if kind == "p8" else FLOOR_TOM, vel, True)
                length = 0.3 if kind == "p8" else 0.18
            else:
                vel = 124 if kind == "q" else 116
                drum(out, off, SNARE, vel, True)
                drum(out, off, FLOOR_TOM, vel - 10, True)
                kick(out, off, vel, True)
                length = 0.4 if kind == "q" else 0.28
            root = root_at(out, off)
            score.add("synth_bass", base + off, length, into_range(root, 28, 39), vel)
            score.add("sub_bass", base + off, length, into_range(root, 28, 39), vel)
            if not soft:
                p = into_range(root, 40, 51)
                for q in (p, p + 7, p + 12):
                    score.add("power", base + off, length, q, vel - 6)
                if kind == "q":
                    score.add("trombone", base + off, 0.35, into_range(root, 36, 47), 116)
                    score.add("trombone", base + off, 0.35, into_range(root, 36, 47) + 7, 116)
                    score.add("tuba", base + off, 0.35, into_range(root, 29, 40), 116)

    # --- 濁り: 区切りの頭の 1 拍目に、低い金管の短 2 度 + 増 4 度。ヴィオラに短 2 度 ---
    if spec.get("dark"):
        for (out, bar, mode, level, first, end, _) in placed:
            if not first or mode not in ("build", "mid", "peak"):
                continue
            root = root_at(out, 0)
            low = into_range(root, 43, 54)
            for p in (low, low + 1, low + 6):
                score.add("trombone", out * beats, 0.4, p, 122)
            score.add("tuba", out * beats, 0.4, into_range(root, 29, 40), 122)
            score.add("viola", out * beats, 0.3, into_range(root, 60, 71) + 1, 112)

    # --- 揺れ: 伸ばす音にビブラートと強さの動き。リードの 2 つ目は少し高くずらす ---
    tempo = spec["tempo"]
    score.shape("lead", tempo, vibrato=16, swell=(0.78, 1.0, 0.86))
    score.shape("lead2", tempo, vibrato=12, swell=(0.78, 1.0, 0.86), detune=9, rate=5.1, phase=1.3)
    score.shape("solo", tempo, vibrato=10, swell=(0.84, 1.0, 0.9), rate=5.9)
    score.shape("choir", tempo, vibrato=5, swell=(0.6, 1.0, 0.7), rate=4.6, min_seconds=0.5, delay=0.0)
    score.shape("warm_pad", tempo, vibrato=9, swell=(0.6, 1.0, 0.7), rate=4.3, phase=2.0, min_seconds=0.5, delay=0.0)

    return score, total_bars * beats, sections
