#!/usr/bin/env python3
"""書き出した音（WAV。ループの長さのあとに残響の尾が付いている）を、ループする ogg にし、測った値を出す。

使い方: finish.py <WAV> <ループの秒数> <書き出す ogg>

- 尾（ループの終わりより後の音）は、頭に重ねる（ループして頭へ戻ったときに、残響が途切れない）。
- 大きさは、積分ラウドネス（EBU R128）が TARGET_LUFS になるようにそろえる。ピークが PEAK_LIMIT_DB を超える曲は、
  第 4 引数に limit を付けると、超える山だけを抑えて（limit()）ねらいの大きさまで上げる。付けなければ、ピークまでで止める。
  強弱の差がある曲は、強い所の山がつかえて全体が上がりきらないので、これを使う（swell.py の版）。
  ゲームの側の大きさ（game/sound_catalog.gd の volume_db）は、出てきた「ねらいとの差」から決める。
- 測るもの: 長さ、積分ラウドネス、ピーク、つなぎ目の段差（README.md の「測り」）、4 小節ごとの大きさ、スペクトルの重心。
"""
import subprocess
import sys

import numpy as np
import pyloudnorm
import soundfile

TARGET_LUFS = -16.0
PEAK_LIMIT_DB = -1.0


def seam_ratio(audio):
    """つなぎ目（終わり -> 頭）の隣り合う標本の差を、曲全体の差の 99.5 パーセンタイルと比べた比。"""
    mono = audio.mean(axis=1)
    diffs = np.abs(np.diff(mono))
    seam = abs(mono[0] - mono[-1])
    return seam / np.percentile(diffs, 99.5)


def limit(loop, rate, ceiling):
    """ceiling を超える山だけを抑える（ループの輪として扱う）。超える所の前後 5 ms の最大から下げ幅を決め、20 ms でならす。"""
    from scipy.ndimage import maximum_filter1d, uniform_filter1d
    env = maximum_filter1d(np.max(np.abs(loop), axis=1), int(0.010 * rate) | 1, mode="wrap")
    gain = np.minimum(1.0, ceiling / np.maximum(env, 1e-9))
    # ならしても下げ幅が足りなくならないように、先に 20 ms の最小を取る。
    gain = -maximum_filter1d(-gain, int(0.020 * rate) | 1, mode="wrap")
    gain = uniform_filter1d(gain, int(0.020 * rate) | 1, mode="wrap")
    return loop * gain[:, None]


def main():
    if len(sys.argv) not in (4, 5) or (len(sys.argv) == 5 and sys.argv[4] != "limit"):
        raise SystemExit("使い方: finish.py <WAV> <ループの秒数> <書き出す ogg> [limit]")
    src, loop_seconds, out = sys.argv[1], float(sys.argv[2]), sys.argv[3]
    use_limit = len(sys.argv) == 5
    audio, rate = soundfile.read(src, always_2d=True)
    n = int(round(loop_seconds * rate))
    if audio.shape[0] < n:
        audio = np.vstack([audio, np.zeros((n - audio.shape[0], audio.shape[1]))])
    loop = audio[:n].copy()
    tail = audio[n:]
    # 尾を頭に重ねる（ループより長い尾は無い前提。あれば何周でも重ねる）。
    for start in range(0, tail.shape[0], n):
        piece = tail[start:start + n]
        loop[: piece.shape[0]] += piece

    meter = pyloudnorm.Meter(rate)
    lufs = meter.integrated_loudness(np.vstack([loop, loop]))
    gain_db = TARGET_LUFS - lufs
    peak_db = 20 * np.log10(np.max(np.abs(loop)) + 1e-12)
    limited = ""
    if peak_db + gain_db > PEAK_LIMIT_DB and use_limit:
        ceiling = 10 ** (PEAK_LIMIT_DB / 20)
        raw = loop
        for _ in range(4):  # 山を抑えると少し小さくなるので、ねらいに合うまで上げ直す。
            loop = limit(raw * 10 ** (gain_db / 20), rate, ceiling)
            gain_db += TARGET_LUFS - meter.integrated_loudness(np.vstack([loop, loop]))
        over = np.mean(np.max(np.abs(raw), axis=1) * 10 ** (gain_db / 20) > ceiling)
        limited = f" / 山を抑えた標本 {over * 100:.2f}%"
    else:
        if peak_db + gain_db > PEAK_LIMIT_DB:
            gain_db = PEAK_LIMIT_DB - peak_db
        loop *= 10 ** (gain_db / 20)
    final_lufs = meter.integrated_loudness(np.vstack([loop, loop]))

    wav = out.rsplit(".", 1)[0] + ".loop.wav"
    soundfile.write(wav, loop, rate, subtype="PCM_16")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-map_metadata", "-1",
                    "-c:a", "libvorbis", "-q:a", "4", out], check=True)

    # 測り（ogg にする前の音で）。
    mono = loop.mean(axis=1)
    spectrum = np.abs(np.fft.rfft(mono * np.hanning(len(mono))))
    freqs = np.fft.rfftfreq(len(mono), 1 / rate)
    centroid = float((spectrum * freqs).sum() / spectrum.sum())
    low = float((spectrum[freqs < 150] ** 2).sum() / (spectrum ** 2).sum())
    print(f"長さ {n / rate:.2f} 秒 / 積分ラウドネス {final_lufs:.1f} LUFS（そろえる前 {lufs:.1f}、上げ下げ {gain_db:+.1f} dB）"
          f" / ピーク {20 * np.log10(np.max(np.abs(loop))):.1f} dBFS{limited}")
    print(f"つなぎ目の段差 {seam_ratio(loop):.2f}（まわりの 99.5 パーセンタイルとの比。1 未満ならふだんの差に紛れる）")
    print(f"スペクトルの重心 {centroid:.0f} Hz / 150 Hz 未満の力の割合 {low * 100:.1f}%")
    seconds_per_chunk = max(1, int(len(mono) / rate / 16))
    chunks = []
    for start in range(0, len(mono), seconds_per_chunk * rate):
        piece = mono[start:start + seconds_per_chunk * rate]
        chunks.append(20 * np.log10(np.sqrt(np.mean(piece ** 2)) + 1e-12))
    print(f"{seconds_per_chunk} 秒ごとの大きさ（dBFS RMS）: " + " ".join(f"{c:.0f}" for c in chunks))


if __name__ == "__main__":
    main()
