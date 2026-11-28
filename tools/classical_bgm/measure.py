#!/usr/bin/env python3
"""曲の「圧」を数字で測る（耳の代わりの物差し。README.md の「圧の物差し」）。

使い方:
  measure.py <音のファイル>...（ogg・wav）            圧と明るさ（1 曲 1 行）
  measure.py --motif <音> <.motifs> [<音> <.motifs>]...   動機の所の打ち方（音は書き出したままの WAV。arrange.py が .motifs を書く）
  measure.py --wobble <MIDI>...                       伸ばす音の揺れ（楽器ごとに書き出して測る。SF2 にサウンドフォント）
                                                      STEMS=<場所> を付けると、書き出さずに、そこの <楽器>.wav を測る（tones.py の --stems）

出す値（1 曲 1 行）:
- 長さ（秒）
- 低域: 60〜200 Hz の力の割合（%）と、60 Hz 未満の割合。太い低音があるほど 60〜200 Hz が大きい。
- 立ち上がり / 秒: 音の立ち上がり（スペクトルの増え方の山）の 1 秒あたりの数。刻みと打楽器が多いほど大きい。
- 立ち上がりの強さ: 立ち上がりの山の高さの中央値を、曲全体の増え方の中央値で割った比。拍がはっきりしているほど大きい。
- 短い区間の大きさ（3 秒の窓を 1 秒ずつずらした短期ラウドネス、LUFS）の
  - 幅: 95 パーセンタイル − 10 パーセンタイル（LU）。大きいほど、弱い所と強い所の差がある（なだらかに大きくなる・静かな所がある）。
  - 谷: 中央値 − 最小（LU）。曲の中でいちばん弱まる所が、ふだんからどれだけ下がるか。
- 頭の強さ: 初めの 3 秒の短期ラウドネス − 曲全体の中央値（LU）。0 に近いほど、頭からいきなり強い。
- 切れ / 分: 50 ms ごとの大きさ（RMS）が、直前の 0.5 秒の平均より 10 dB 以上下がった所（強打のあとの一瞬の無音、溜め）の 1 分あたりの数。
  3 秒の窓では見えない短い「間」を数える。

明るさ（--motif・--wobble でないとき、圧の値に続けて出す）:
- 200 Hz 未満・2 kHz 以上: その帯域の力の割合（%）。
- 高 ÷ 低: 2 kHz 以上の力 ÷ 200 Hz 未満の力（dB）。小さいほど暗い。人間が「明るすぎる」と言った版（電重・電中・電全）は -4.5〜-5.1、
  良いと言った版（電2・重・夏）は -7.6〜-13.8 で、分かれる。

動機の所（--motif）: 動機「16 分 1 つ + 32 分 6 つ + 16 分 4 つ」ごとに測り、中央値を出す。
- タンッの立ち上がり: 終わりの 16 分 4 つのそれぞれで、打つ直前（16 分の半分）の底から、打った直後の山までの上がり幅（dB。5 ms の RMS）。
- タンッの隙間: 打った山から、次の音の前の底までの下がり幅（dB）。大きいほど、1 音ずつ区切れている。
- 走る音の高 ÷ 低: 32 分 6 つの所（16 分 3 つぶん）の、2 kHz 以上の力 ÷ 200 Hz 未満の力（dB）。大きいほど、速い音が高い所で鳴っている（軽い）。
- 走る音の刻み: その所の、250 Hz 未満の大きさの揺れ幅（90 − 10 パーセンタイル、dB）。大きいほど、低い所で 1 音ずつ打っている。

伸ばす音の揺れ（--wobble）: MIDI の楽器を 1 つずつ書き出し、0.3 秒より長い音（打楽器を除く）ごとに、頭の 0.2 秒のあとを測る。
- 高さの揺れ: その音の基音のまわり（±1.5 半音）の瞬時周波数の標準偏差（セント）。
- 大きさの揺れ: 20 ms ごとの大きさの標準偏差（dB）。
- 出す値: 伸ばす音の長さの合計（1 分あたりの秒。楽器ごとに足す）、高さ・大きさの揺れ（長さで重みを付けた中央値）、
  高さの止まった音（高さの揺れ 5 セント未満）と、大きさの止まった音（大きさの揺れ 0.7 dB 未満）の長さの合計（1 分あたりの秒）。
- 和音を鳴らす楽器（ギター・パッド）の高さの揺れは、ほかの音の倍音が混ざるので当てにならない。旋律の楽器（リード・独奏）で見る。
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
import pyloudnorm
import soundfile


def short_term(audio, rate, window=3.0, hop=1.0):
    meter = pyloudnorm.Meter(rate)
    n, h = int(window * rate), int(hop * rate)
    values = []
    for start in range(0, max(1, len(audio) - n + 1), h):
        piece = audio[start:start + n]
        values.append(meter.integrated_loudness(piece) if len(piece) == n else -70.0)
    return np.array(values)


def onsets(mono, rate):
    """スペクトルの増え方（spectral flux）の山を数える。"""
    size, hop = 2048, 512
    window = np.hanning(size)
    frames = [np.abs(np.fft.rfft(mono[i:i + size] * window)) for i in range(0, len(mono) - size, hop)]
    mag = np.log1p(np.array(frames) * 10)
    flux = np.maximum(mag[1:] - mag[:-1], 0).sum(axis=1)
    # 山: 前後 3 フレーム（約 35 ms）でいちばん大きく、近くの平均を越えるもの。
    peaks = []
    for i in range(3, len(flux) - 3):
        local = flux[max(0, i - 20):i + 20]
        if flux[i] == flux[i - 3:i + 4].max() and flux[i] > local.mean() + 0.5 * local.std():
            peaks.append(flux[i])
    seconds = len(mono) / rate
    strength = float(np.median(peaks) / np.median(flux)) if peaks else 0.0
    return len(peaks) / seconds, strength


def cuts(mono, rate):
    """強打のあとの一瞬の無音（溜め）の数（1 分あたり）。"""
    frame = int(0.05 * rate)
    rms = np.array([np.sqrt(np.mean(mono[i:i + frame] ** 2)) + 1e-9 for i in range(0, len(mono) - frame, frame)])
    db = 20 * np.log10(rms)
    count, i = 0, 10
    while i < len(db):
        if db[i] < 10 * np.log10(np.mean(rms[i - 10:i] ** 2)) - 10:
            count += 1
            i += 10  # 同じ溜めを 2 度数えない
        else:
            i += 1
    return count / (len(mono) / rate / 60)


def measure(path):
    audio, rate = soundfile.read(path, always_2d=True)
    mono = audio.mean(axis=1)
    spectrum = np.abs(np.fft.rfft(mono)) ** 2
    freqs = np.fft.rfftfreq(len(mono), 1 / rate)
    total = spectrum.sum()
    low = spectrum[(freqs >= 60) & (freqs < 200)].sum() / total
    sub = spectrum[freqs < 60].sum() / total
    per_second, strength = onsets(mono, rate)
    st = short_term(audio, rate)
    st = st[st > -60]
    head = st[0] - np.median(st)
    bright = brightness(mono, rate)
    return {
        "長さ": f"{len(mono) / rate:.0f} 秒",
        "60-200Hz": f"{low * 100:.1f}%",
        "60Hz 未満": f"{sub * 100:.1f}%",
        "立ち上がり/秒": f"{per_second:.1f}",
        "立ち上がりの強さ": f"{strength:.1f}",
        "幅": f"{np.percentile(st, 95) - np.percentile(st, 10):.1f} LU",
        "谷": f"{np.median(st) - st.min():.1f} LU",
        "頭の強さ": f"{head:+.1f} LU",
        "切れ/分": f"{cuts(mono, rate):.1f}",
        "200Hz 未満": f"{bright[0] * 100:.0f}%",
        "2kHz 以上": f"{bright[1] * 100:.1f}%",
        "高 ÷ 低": f"{bright[2]:+.1f} dB",
    }


def brightness(mono, rate):
    from scipy.signal import stft
    f, _t, z = stft(mono, rate, nperseg=4096, noverlap=2048)
    power = (np.abs(z) ** 2).sum(axis=1)
    low, high = power[f < 200].sum(), power[f >= 2000].sum()
    return low / power.sum(), high / power.sum(), 10 * np.log10(high / low)


def envelope(x, rate, hop=0.005):
    n = int(hop * rate)
    return np.array([10 * np.log10(np.mean(x[i:i + n] ** 2) + 1e-12) for i in range(0, len(x) - n, n)])


def motif(path, motifs_path):
    from scipy.signal import butter, sosfiltfilt
    audio, rate = soundfile.read(path, always_2d=True)
    mono = audio.mean(axis=1)
    env = envelope(mono, rate)
    low = sosfiltfilt(butter(4, 250, btype="low", fs=rate, output="sos"), mono)
    low_env = envelope(low, rate)
    at = lambda sec: int(round(sec / 0.005))
    rises, gaps, tilt, chop = [], [], [], []
    for line in open(motifs_path):
        t0, beat = (float(v) for v in line.split())
        six = beat / 4
        for k in range(4):
            t = t0 + beat + k * six
            before = env[at(t - six / 2):at(t) + 1].min()
            top = env[at(t):at(t + six * 0.5) + 1].max()
            after = env[at(t + six * 0.4):at(t + six) + 1].min()
            rises.append(top - before)
            gaps.append(top - after)
        a, b = int((t0 + six) * rate), int((t0 + beat) * rate)
        _lo, _hi, ratio = brightness(mono[a:b], rate) if b - a >= 4096 else (0, 0, float("nan"))
        tilt.append(ratio)
        seg = low_env[at(t0 + six):at(t0 + beat)]
        chop.append(np.percentile(seg, 90) - np.percentile(seg, 10))
    return {
        "動機の数": f"{len(tilt)}",
        "タンッの立ち上がり": f"{np.median(rises):.1f} dB",
        "タンッの隙間": f"{np.median(gaps):.1f} dB",
        "走る音の高 ÷ 低": f"{np.nanmedian(tilt):+.1f} dB",
        "走る音の刻み（低域）": f"{np.median(chop):.1f} dB",
    }


def wobble(midi_path):
    """伸ばす音の揺れ。楽器（トラック）ごとに書き出して測る。"""
    import mido
    from scipy.signal import butter, sosfiltfilt, hilbert
    sf2 = os.environ.get("SF2", "/usr/share/sounds/sf2/FluidR3_GM.sf2")
    stems = os.environ.get("STEMS")
    mid = mido.MidiFile(midi_path)
    tempo = next(msg.tempo for msg in mid.tracks[0] if msg.type == "set_tempo")
    per_tick = tempo / 1e6 / mid.ticks_per_beat
    total = sum(msg.time for msg in mid.tracks[0]) * per_tick
    rows = []  # (長さ, 高さの揺れ, 大きさの揺れ)
    per_layer = {}
    with tempfile.TemporaryDirectory() as work:
        for track in mid.tracks[1:]:
            notes, on, now, drums = [], {}, 0, False
            for msg in track:
                now += msg.time
                if msg.type in ("note_on", "note_off"):
                    drums = drums or msg.channel == 9
                    if msg.type == "note_on" and msg.velocity > 0:
                        on.setdefault(msg.note, []).append(now)
                    elif on.get(msg.note):
                        start = on[msg.note].pop(0)
                        notes.append((start * per_tick, now * per_tick, msg.note))
            notes = [n for n in notes if n[1] - n[0] >= 0.3]
            if drums or not notes:
                continue
            one = mido.MidiFile(type=1, ticks_per_beat=mid.ticks_per_beat)
            one.tracks.append(mid.tracks[0])
            one.tracks.append(track)
            one.save(f"{work}/one.mid")
            if stems:  # 音色の組（tones.py）で鳴らした、楽器ごとの音。
                audio, rate = soundfile.read(os.path.join(stems, track.name + ".wav"), always_2d=True)
            else:
                subprocess.run(["fluidsynth", "-ni", "-q", "-g", "0.6", "-r", "44100", "-R", "0", "-C", "0", "-T", "wav",
                                "-F", f"{work}/one.wav", sf2, f"{work}/one.mid"], check=True, stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL)
                audio, rate = soundfile.read(f"{work}/one.wav", always_2d=True)
            mono = audio.mean(axis=1)
            mine = []
            filtered = {}
            for (start, end, pitch) in notes:
                i, j = int((start + 0.2) * rate), int((end - 0.03) * rate)
                if j - i < int(0.08 * rate) or j > len(mono):
                    continue
                f0 = 440.0 * 2 ** ((pitch - 69) / 12)
                if pitch not in filtered:
                    sos = butter(4, [f0 * 2 ** (-1.5 / 12), f0 * 2 ** (1.5 / 12)], btype="band", fs=rate, output="sos")
                    filtered[pitch] = sosfiltfilt(sos, mono)
                pad = int(0.05 * rate)
                phase = np.unwrap(np.angle(hilbert(filtered[pitch][max(0, i - pad):j + pad])))[i - max(0, i - pad):][:j - i]
                inst = np.diff(phase) * rate / (2 * np.pi)
                k = int(0.02 * rate)
                inst = np.convolve(inst, np.ones(k) / k, mode="valid")
                cents = 1200 * np.log2(np.maximum(inst, 1.0) / f0)
                frame = int(0.02 * rate)
                seg = mono[i:j]
                level = np.array([10 * np.log10(np.mean(seg[a:a + frame] ** 2) + 1e-12) for a in range(0, len(seg) - frame + 1, frame)])
                mine.append((end - start, float(cents.std()), float(level.std()) if len(level) > 1 else 0.0))
            rows += mine
            per_layer[track.name] = mine

    def weighted_median(pairs):
        pairs = sorted(pairs)
        half, acc = sum(w for (_v, w) in pairs) / 2, 0.0
        for (v, w) in pairs:
            acc += w
            if acc >= half:
                return v
        return 0.0

    def summary(mine):
        if not mine:
            return None
        seconds = sum(r[0] for r in mine)
        still_pitch = sum(r[0] for r in mine if r[1] < 5.0)
        still_level = sum(r[0] for r in mine if r[2] < 0.7)
        return (seconds / total * 60, weighted_median([(r[1], r[0]) for r in mine]),
                weighted_median([(r[2], r[0]) for r in mine]), still_pitch / total * 60, still_level / total * 60)

    out = []
    for name, mine in [("全部", rows)] + sorted(per_layer.items()):
        s = summary(mine)
        if s:
            out.append((name, {"伸ばす音 秒/分": f"{s[0]:.1f}", "高さの揺れ": f"{s[1]:.1f} セント",
                               "大きさの揺れ": f"{s[2]:.2f} dB", "高さの止まった音 秒/分": f"{s[3]:.1f}",
                               "大きさの止まった音 秒/分": f"{s[4]:.1f}"}))
    return out


def table(rows, head="ファイル"):
    keys = list(rows[0][1])
    print(f"| {head} | " + " | ".join(keys) + " |")
    print("| --- |" + " --- |" * len(keys))
    for name, m in rows:
        print(f"| `{name}` | " + " | ".join(m[k] for k in keys) + " |")


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    if sys.argv[1] == "--motif":
        args = sys.argv[2:]
        table([(args[i].rsplit("/", 1)[-1], motif(args[i], args[i + 1])) for i in range(0, len(args) - 1, 2)])
        return
    if sys.argv[1] == "--wobble":
        for path in sys.argv[2:]:
            print(f"\n{path.rsplit('/', 1)[-1]}")
            table(wobble(path), "楽器")
        return
    table([(p.rsplit("/", 1)[-1], measure(p)) for p in sys.argv[1:]])


if __name__ == "__main__":
    main()
