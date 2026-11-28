#!/usr/bin/env python3
"""緩急と主旋律を、区切りごとに測る（耳の代わりの物差し。README.md）。

使い方: sections.py <全部の WAV> <旋律だけの WAV> <伴奏だけの WAV> <区切りのファイル（arrange.py が書く .sections）>

3 つの WAV は、同じ MIDI から同じ設定で書き出したもの（そろえる前。大きさの差だけを見る）。
区切りごとに出す値:
- 大きさ: 全部の音のラウドネス（LUFS）を、曲全体との差（LU）で。
- 密度: 音の立ち上がり（measure.py と同じ数え方）の 1 秒あたりの数。
- 旋律 − 伴奏: 旋律だけの音と伴奏だけの音の大きさの差（dB）。全体と、旋律の音域（500〜4000 Hz）で。
- 旋律の鳴っている割合: 50 ms ごとに、旋律だけの音が曲の旋律の大きさの中央値より 20 dB 下を上回る割合。
終わりに、曲全体の値と、役ごと（calm / solo / build / peak）の平均、いちばん強い区切りと弱い区切りの差を出す。
"""
import sys

import numpy as np
import pyloudnorm
import soundfile
from scipy.signal import butter, sosfilt

from measure import onsets


def db(x):
    return 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)


def band(x, rate, lo=500, hi=4000):
    return sosfilt(butter(4, [lo, hi], btype="band", fs=rate, output="sos"), x)


def main():
    if len(sys.argv) != 5:
        raise SystemExit(__doc__)
    full, rate = soundfile.read(sys.argv[1], always_2d=True)
    mel = soundfile.read(sys.argv[2], always_2d=True)[0].mean(axis=1)
    back = soundfile.read(sys.argv[3], always_2d=True)[0].mean(axis=1)
    sections = [line.split() for line in open(sys.argv[4])]
    end = int(float(sections[-1][1]) * rate)
    meter = pyloudnorm.Meter(rate)
    whole = meter.integrated_loudness(full[:end])
    mono = full.mean(axis=1)
    frame = int(0.05 * rate)
    mel_frames = np.array([db(mel[i:i + frame]) for i in range(0, min(end, len(mel)) - frame, frame)])
    floor = np.median(mel_frames[mel_frames > -80]) - 20
    mel_band, back_band = band(mel, rate), band(back, rate)

    print("| 区切り（元の小節） | 役 | 秒 | 大きさ | 密度 / 秒 | 旋律 − 伴奏 | 〃（500〜4000 Hz） | 旋律の鳴っている割合 |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- |")
    rows = []
    for (a, b, mode, bars) in sections:
        i, j = int(float(a) * rate), int(float(b) * rate)
        piece = full[i:j]
        loud = meter.integrated_loudness(piece) - whole if j - i > 0.5 * rate else float("nan")
        dens = onsets(mono[i:j], rate)[0]
        diff = db(mel[i:j]) - db(back[i:j])
        diff_band = db(mel_band[i:j]) - db(back_band[i:j])
        active = float(np.mean(mel_frames[i // frame:j // frame] > floor))
        rows.append((mode, float(b) - float(a), loud, dens, diff, diff_band, active))
        print(f"| {bars} | {mode} | {float(a):.0f}〜{float(b):.0f} | {loud:+.1f} LU | {dens:.1f} | {diff:+.1f} dB | {diff_band:+.1f} dB | {active * 100:.0f}% |")
    print()
    louds = [r[2] for r in rows if r[1] >= 3.0 and not np.isnan(r[2])]
    denss = [r[3] for r in rows if r[1] >= 3.0]
    total = sum(r[1] for r in rows)
    print(f"区切りの大きさの差（3 秒より長い区切りの、いちばん強い − いちばん弱い）: {max(louds) - min(louds):.1f} LU"
          f" / 密度の比（いちばん多い ÷ いちばん少ない）: {max(denss) / max(min(denss), 0.1):.1f}")
    print(f"曲全体: 旋律 − 伴奏 {db(mel[:end]) - db(back[:end]):+.1f} dB（500〜4000 Hz {db(mel_band[:end]) - db(back_band[:end]):+.1f} dB）"
          f" / 旋律の鳴っている割合 {sum(r[6] * r[1] for r in rows) / total * 100:.0f}%")
    modes = []
    for r in rows:
        if r[0] not in modes:
            modes.append(r[0])
    for mode in modes:
        mine = [r for r in rows if r[0] == mode]
        t = sum(r[1] for r in mine)
        avg = lambda k: sum(r[k] * r[1] for r in mine if not np.isnan(r[k])) / t
        print(f"- {mode}: {t:.0f} 秒 / 大きさ {avg(2):+.1f} LU / 密度 {avg(3):.1f} / 旋律 − 伴奏 {avg(4):+.1f} dB（音域 {avg(5):+.1f} dB）/ 鳴っている割合 {avg(6) * 100:.0f}%")


if __name__ == "__main__":
    main()
