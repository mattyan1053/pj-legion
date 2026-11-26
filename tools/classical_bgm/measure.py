#!/usr/bin/env python3
"""曲の「圧」を数字で測る（耳の代わりの物差し。README.md の「圧の物差し」）。

使い方: measure.py <音のファイル>...（ogg・wav）

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
"""
import sys

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
    }


def main():
    if len(sys.argv) < 2:
        raise SystemExit("使い方: measure.py <音のファイル>...")
    rows = [(p.rsplit("/", 1)[-1], measure(p)) for p in sys.argv[1:]]
    keys = list(rows[0][1])
    print("| ファイル | " + " | ".join(keys) + " |")
    print("| --- |" + " --- |" * len(keys))
    for name, m in rows:
        print(f"| `{name}` | " + " | ".join(m[k] for k in keys) + " |")


if __name__ == "__main__":
    main()
