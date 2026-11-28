#!/usr/bin/env python3
"""編曲の MIDI を、楽器ごとに別の音源で音にして混ぜる（音色の組。README.md の「音色の組」）。

使い方: tones.py <編曲の MIDI> <音色の組> <書き出す WAV> [--stems <楽器ごとの音を置く場所>]

arrange.py の書き出す MIDI は、楽器（CHANNELS の名前）ごとに 1 トラック。ここでは音符を変えず、
トラックごとに TONES の表の音源（1 つか、重ねる 2〜3 つ）で鳴らし、帯域・歪み・広がりを整えて、1 つの残響に送って混ぜる。

音源の種類（表の "engine"）:
- sf2: サウンドフォントを FluidSynth で鳴らす（残響・コーラスなし）。"font" は SOUNDFONTS の名前、"bank"・"program" は音色。
  "keys" は鳴らす鍵（ドラムを 2 つの音源に分ける）、"detune" はセント、"delay" は秒（左右に置いた 2 本の重ね）。
- sampler: 録った音（WAV。1 音 1 ファイル）を、音の高さに合わせて鳴らす。VSCO 2 CE（CC0）用。
  "short"・"long" は短い音・長い音に使うフォルダ（音の長さが "split" 秒より短ければ short）。
- synth: スクリプトで作るシンセ（少しずつ高さをずらしたノコギリ波の重ね。音源のファイルは要らない）。

音量の釣り合いは、もとの版（FluidR3_GM で鳴らした同じトラック）の大きさに楽器ごとに合わせてから、"trim"（dB）だけ動かす。
音源を替えても、編曲の釣り合いが崩れないようにするため。

音源の場所は環境変数で渡す（build.sh）: SF2（FluidR3_GM）、SF2_MUSESCORE、SF2_DRUMS、VSCO（VSCO 2 CE を置いた場所）。
音源そのものはリポジトリに入れない。出どころとライセンスは assets/audio/classical/README.md。
"""
import os
import re
import subprocess
import sys
import tempfile

import mido
import numpy as np
import soundfile

import finish

RATE = 44100

SOUNDFONTS = {
    "fluid": ("SF2", "/usr/share/sounds/sf2/FluidR3_GM.sf2"),
    "musescore": ("SF2_MUSESCORE", "/usr/share/sounds/sf2/MuseScore_General_Full.sf2"),
    "drums": ("SF2_DRUMS", "/usr/share/sounds/sf2/Red_Zeppelin_4_LV2.sf2"),
}
VSCO_DIR = ("VSCO", "/usr/share/sounds/vsco2-ce")


def sf2(font, bank, program, **more):
    return dict(engine="sf2", font=font, bank=bank, program=program, **more)


def sampler(short, long, split=0.22, **more):
    return dict(engine="sampler", short=short, long=long, split=split, **more)


def synth(**more):
    return dict(engine="synth", **more)


# 音色の組 -> 楽器 -> 設定。
#   sources: 重ねる音源（weight は重ねの中の比。既定 1）
#   hp / lp: 通す帯域（Hz）、drive: 歪みの深さ（0 で無し）、width: 左右の広がり（1 でそのまま）、
#   send: 残響へ送る量（0〜1）、trim: もとの版の大きさからの上げ下げ（dB）
# 表に無い楽器は、もとのまま（FluidR3_GM の、MIDI に書いてある音色）で鳴らす。
TONES = {
    "blend": {
        # 独奏ヴァイオリン: 録った独奏（弓のビブラートが入っている）+ MuseScore のヴァイオリン。
        "solo": dict(sources=[sampler("Strings/Solo Violin/spic", "Strings/Solo Violin/Arco Vib", weight=1.0),
                              sf2("musescore", 0, 40, weight=0.6)],
                     hp=180, lp=7000, send=0.30, width=0.8),
        # 弦の合奏: MuseScore_General の、パートごとの合奏（第 1・第 2 ヴァイオリン）と弦の合奏。
        "violin1": dict(sources=[sf2("musescore", 20, 48)], hp=180, lp=3000, send=0.32),
        "violin2": dict(sources=[sf2("musescore", 25, 48)], hp=180, lp=2800, send=0.32),
        "viola": dict(sources=[sf2("musescore", 0, 48)], hp=120, lp=7000, send=0.30),
        "low_strings": dict(sources=[sf2("musescore", 0, 48, weight=1.0),
                                     sampler("Strings/Cello Section/spic", "Strings/Cello Section/susvib", weight=0.8)],
                            hp=70, lp=6000, send=0.30),
        "cello": dict(sources=[sampler("Strings/Cello Section/spic", "Strings/Cello Section/susvib", weight=1.0),
                               sf2("musescore", 0, 42, weight=0.6)],
                      hp=55, lp=6000, send=0.26),
        # 低い金管: 録ったトロンボーンとチューバ（短い音はスタッカートの録音）。
        "trombone": dict(sources=[sampler("Brass/Tenor Trombone/stac", "Brass/Tenor Trombone/sus", weight=1.0),
                                  sf2("musescore", 0, 57, weight=0.5)],
                         hp=60, lp=5000, drive=0.4, send=0.34),
        "tuba": dict(sources=[sampler("Brass/Tuba/stac", "Brass/Tuba/sus", weight=1.0),
                              sf2("musescore", 0, 58, weight=0.5)],
                     hp=35, lp=3500, drive=0.3, send=0.28),
        # リード: 作ったシンセ（7 本の重ね。音の頭で開いて閉じるフィルター、ゆっくりした明るさの揺れ）+ シンセブラス。
        "lead": dict(sources=[synth(voices=7, spread=14, low=900, high=3400, decay=0.28, sustain=0.38, weight=1.0),
                              sf2("musescore", 0, 62, weight=0.7)],
                     hp=90, lp=5200, drive=0.5, width=1.25, send=0.24),
        "lead2": dict(sources=[sf2("musescore", 20, 81)], hp=140, lp=4200, drive=0.3, width=1.3, send=0.24),
        # 低音: シンセベース + 作ったシンセ（ノコギリ波 + 基音の正弦波）。歪ませて倍音を足す。
        "synth_bass": dict(sources=[sf2("musescore", 0, 38, weight=1.0),
                                    synth(voices=3, spread=7, low=420, high=1500, decay=0.12, sustain=0.25, sub=0.15,
                                          stereo=0.0, weight=0.7)],
                           hp=48, lp=3200, drive=0.9, width=0.0, send=0.03),
        "sub_bass": dict(sources=[synth(voices=2, spread=5, low=300, high=800, decay=0.18, sustain=0.35, sub=0.25,
                                        stereo=0.0, weight=1.0),
                                  sf2("musescore", 0, 39, weight=0.5)],
                         hp=48, lp=1200, drive=0.8, width=0.0, send=0.0),
        # 歪んだギター: 少し高さをずらした 2 本を左右に置き、あとから歪みを足して、スピーカーの帯域に絞る。
        "power": dict(sources=[sf2("musescore", 0, 30, detune=-6, pan=24, weight=1.0),
                               sf2("musescore", 0, 30, detune=7, pan=104, delay=0.013, weight=1.0)],
                      hp=85, lp=4300, drive=0.9, send=0.10),
        # パッド: 合唱 2 つ（あー + うー）と、暖かいパッド。「あー」は FluidR3_GM のまま、「うー」は薄く。
        # MuseScore_General の合唱は高さの揺れが小さく、主にすると「高さの止まった伸ばす音」が 0 → 18 秒 / 分に増えた（測って戻した）。
        "choir": dict(sources=[sf2("fluid", 0, 52, weight=1.0), sf2("musescore", 0, 53, weight=0.3, detune=5)],
                      hp=150, lp=5000, width=1.4, send=0.5),
        "warm_pad": dict(sources=[sf2("musescore", 0, 89)], hp=60, lp=3000, width=1.4, send=0.4),
        # ドラム: 生のロックのキット。大太鼓（35 番）はキットに無いので、オーケストラの大太鼓。
        "drums": dict(sources=[sf2("drums", 0, 0, keys="kit", weight=1.0),
                               sf2("musescore", 128, 48, keys=(35,), weight=1.0)],
                      hp=45, drive=0.2, send=0.10),
    },
}
# 生のキットに無い鍵の読み替え（GM の鍵 -> AVL Drumkits の鍵）。無い鍵（35）は別の音源へ。
KIT_KEYS = {36: 36, 37: 37, 38: 38, 40: 40, 41: 41, 42: 42, 43: 43, 44: 44, 45: 45, 46: 46, 47: 47, 48: 47, 49: 49,
            51: 51, 57: 49}
BUS = dict(reverb_seconds=1.5, reverb_level=0.32, ceiling=1.6)


def font_path(name):
    env, default = SOUNDFONTS[name]
    path = os.environ.get(env, default)
    if not os.path.isfile(path):
        raise SystemExit(f"音源が無い: {path}（{env} にパスを入れる。README.md の「要るもの」）")
    return path


# ---------- MIDI を読む ----------

class Track:
    def __init__(self, name):
        self.name = name
        self.messages = []  # (秒, tick, mido のメッセージ)
        self.notes = []     # (始まりの秒, 終わりの秒, 高さ, 強さ)
        self.bends = [(0.0, 0.0)]   # (秒, セント)
        self.express = [(0.0, 1.0)]  # (秒, 0〜1)
        self.volume, self.pan = 100, 64


def read_midi(path):
    mid = mido.MidiFile(path)
    tempo = next(m.tempo for m in mid.tracks[0] if m.type == "set_tempo")
    seconds_per_tick = tempo / 1e6 / mid.ticks_per_beat
    total = sum(m.time for m in mid.tracks[0]) * seconds_per_tick
    tracks = []
    for raw in mid.tracks[1:]:
        track = Track(raw.name)
        tick, held = 0, {}
        for m in raw:
            tick += m.time
            if m.is_meta:
                continue
            at = tick * seconds_per_tick
            track.messages.append((at, tick, m))
            if m.type == "note_on" and m.velocity > 0:
                held[m.note] = (at, m.velocity)
            elif m.type in ("note_off", "note_on") and m.note in held:
                start, vel = held.pop(m.note)
                track.notes.append((start, at, m.note, vel))
            elif m.type == "pitchwheel":
                track.bends.append((at, m.pitch / 8192.0 * 200.0))
            elif m.type == "control_change" and m.control == 11:
                track.express.append((at, m.value / 127.0))
            elif m.type == "control_change" and m.control == 7:
                track.volume = m.value
            elif m.type == "control_change" and m.control == 10:
                track.pan = m.value
        track.notes.sort()
        tracks.append(track)
    return mid, tempo, total, tracks


def step_curve(points, times):
    """(秒, 値) の列（階段）を、times の時刻で読む。"""
    at = np.array([p[0] for p in points])
    values = np.array([p[1] for p in points])
    return values[np.clip(np.searchsorted(at, times, side="right") - 1, 0, len(values) - 1)]


def pan_gains(pan):
    angle = np.clip(pan / 127.0, 0, 1) * np.pi / 2
    return np.cos(angle) * np.sqrt(2), np.sin(angle) * np.sqrt(2)


# ---------- 音源: サウンドフォント ----------

def render_sf2(mid, tempo, track, spec, total, work):
    """トラック 1 本を、選んだ音色で鳴らす。spec が None なら、MIDI に書いてある音色のまま（もとの版の大きさを測る用）。"""
    out = mido.MidiFile(type=1, ticks_per_beat=mid.ticks_per_beat)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage("set_tempo", tempo=tempo, time=0))
    meta.append(mido.MetaMessage("end_of_track", time=int(round(total / (tempo / 1e6 / mid.ticks_per_beat)))))
    out.tracks.append(meta)
    body = mido.MidiTrack()
    keys = spec.get("keys") if spec else None
    drum_channel = spec is None and track.name == "drums"
    ch = 9 if drum_channel or (spec and spec["bank"] == 128) else 0
    events = []
    if spec:
        if spec["bank"] != 128:
            events.append((0, 0, mido.Message("control_change", channel=ch, control=0, value=spec["bank"])))
        events.append((0, 0, mido.Message("program_change", channel=ch, program=spec["program"])))
        if spec.get("detune"):
            # 細かい調律（RPN 1）: 8192 が ±0、±8192 で ±100 セント。
            value = int(round(8192 + spec["detune"] / 100.0 * 8192))
            for control, v in ((101, 0), (100, 1), (6, value >> 7), (38, value & 127)):
                events.append((0, 0, mido.Message("control_change", channel=ch, control=control, value=v)))
    for (_at, tick, m) in track.messages:
        if m.type == "program_change" and spec:
            continue
        if m.type in ("note_on", "note_off") and keys is not None:
            if keys == "kit":
                if m.note not in KIT_KEYS:
                    continue
                m = m.copy(note=KIT_KEYS[m.note])
            elif m.note not in keys:
                continue
        if spec and m.type == "control_change" and m.control == 10 and "pan" in spec:
            m = m.copy(value=spec["pan"])
        events.append((tick, 1, m.copy(channel=ch)))
    events.sort(key=lambda e: (e[0], e[1]))
    now = 0
    for (tick, _order, m) in events:
        body.append(m.copy(time=tick - now))
        now = tick
    out.tracks.append(body)
    path = os.path.join(work, "one.mid")
    wav = os.path.join(work, "one.wav")
    out.save(path)
    font = font_path(spec["font"] if spec else "fluid")
    subprocess.run(["fluidsynth", "-ni", "-q", "-g", "0.6", "-r", str(RATE), "-R", "0", "-C", "0", "-T", "wav", "-F", wav,
                    font, path], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    audio, rate = soundfile.read(wav, always_2d=True)
    assert rate == RATE
    n = int(round(total * RATE))
    audio = audio[:n] if len(audio) >= n else np.vstack([audio, np.zeros((n - len(audio), 2))])
    delay = int(round((spec or {}).get("delay", 0) * RATE))
    if delay:
        audio = np.vstack([np.zeros((delay, 2)), audio[:-delay]])
    return audio


# ---------- 音源: 録った音（1 音 1 ファイル） ----------

NOTE_NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
_sample_cache = {}


def measured_pitch(mono, rate):
    """録った音の高さ（MIDI の番号。小数）を、自己相関で測る。"""
    mid = len(mono) // 3
    piece = mono[mid: mid + min(len(mono) - mid, rate // 2)]
    if len(piece) < 2048:
        piece = mono
    piece = piece - piece.mean()
    spectrum = np.fft.rfft(piece * np.hanning(len(piece)), 1 << 17)
    corr = np.fft.irfft(np.abs(spectrum) ** 2)
    lo, hi = int(rate / 2200), int(rate / 25)
    lag = lo + int(np.argmax(corr[lo:hi]))
    return 69 + 12 * np.log2(rate / lag / 440.0)


def load_samples(folder):
    """フォルダの WAV を読み、(高さ, 強さの段) -> 音 の表にする。高さは名前の音名から。オクターブは測って合わせる
    （フォルダによってオクターブの数え方が違うため）。頭の無音は切る。"""
    if folder in _sample_cache:
        return _sample_cache[folder]
    root = os.environ.get(VSCO_DIR[0], VSCO_DIR[1])
    path = os.path.join(root, folder)
    if not os.path.isdir(path):
        raise SystemExit(f"音源が無い: {path}（VSCO に VSCO 2 CE の場所を入れる。README.md の「要るもの」）")
    found_files = []
    for name in sorted(os.listdir(path)):
        found = re.search(r"_([A-G])(#?)(-?\d)_(?:(p|f)\b|v(\d))", name)
        if not name.lower().endswith(".wav") or not found:
            continue
        audio, rate = soundfile.read(os.path.join(path, name), always_2d=True)
        assert rate == RATE, name
        if audio.shape[1] == 1:
            audio = np.repeat(audio, 2, axis=1)
        loud = np.abs(audio).max(axis=1)
        start = max(0, int(np.argmax(loud > 0.03 * loud.max())) - int(0.004 * RATE))
        audio = audio[start:].copy()
        audio[: int(0.002 * RATE)] *= np.linspace(0, 1, int(0.002 * RATE))[:, None]
        named = NOTE_NAMES[found.group(1)] + (1 if found.group(2) else 0) + 12 * (int(found.group(3)) + 1)
        level = {"p": 1, "f": 2}.get(found.group(4)) or int(found.group(5))
        found_files.append((named, level, audio, round((measured_pitch(audio.mean(axis=1), RATE) - named) / 12.0)))
    # オクターブのずれは、フォルダで 1 つ（測った値の中央値。1 音ずつの測りは、短い音で倍音を拾って外れることがある）。
    shift = 12 * int(np.median([f[3] for f in found_files])) if found_files else 0
    table = {}
    for (named, level, audio, _octave) in found_files:
        table.setdefault((named + shift, level), []).append(audio)
    if not table:
        raise SystemExit(f"音が読めない: {path}")
    _sample_cache[folder] = table
    return table


def pick_sample(table, pitch, vel, counter):
    pitches = sorted({p for (p, _l) in table})
    near = min(pitches, key=lambda p: (abs(p - pitch), p))
    levels = sorted(l for (p, l) in table if p == near)
    level = levels[min(len(levels) - 1, int(vel / 128.0 * len(levels)))]
    takes = table[(near, level)]
    counter[(near, level)] = counter.get((near, level), -1) + 1
    return near, takes[counter[(near, level)] % len(takes)]


def render_sampler(track, spec, total):
    n = int(round(total * RATE))
    out = np.zeros((n, 2))
    release = int(spec.get("release", 0.09) * RATE)
    counters = {}
    gl, gr = pan_gains(track.pan)
    for (start, end, pitch, vel) in track.notes:
        folder = spec["short"] if end - start < spec["split"] else spec["long"]
        table = load_samples(folder)
        center, audio = pick_sample(table, pitch, vel, counters.setdefault(folder, {}))
        a = int(round(start * RATE))
        length = min(int(round((end - start) * RATE)) + release, n - a)
        if length <= 0:
            continue
        times = start + np.arange(length) / RATE
        ratio = 2.0 ** ((pitch - center + step_curve(track.bends, times) / 100.0) / 12.0)
        position = np.concatenate([[0.0], np.cumsum(ratio[:-1])])
        inside = position < len(audio) - 1
        piece = np.stack([np.interp(position, np.arange(len(audio)), audio[:, c]) for c in (0, 1)], axis=1) * inside[:, None]
        env = np.ones(length)
        tail = min(release, length)
        env[-tail:] = np.linspace(1, 0, tail) ** 2
        env *= step_curve(track.express, times) * (0.25 + 0.75 * (vel / 127.0) ** 1.4)
        # 録った音は、強さの段ごとに大きさが違う。段の中の差だけを強さで付ける。
        piece *= env[:, None] / (np.sqrt(np.mean(audio[: RATE // 2] ** 2)) + 1e-9)
        out[a: a + length, 0] += piece[:, 0] * gl
        out[a: a + length, 1] += piece[:, 1] * gr
    return out


# ---------- 音源: 作るシンセ ----------

def saw(phase, step):
    """角を丸めたノコギリ波（polyBLEP。折り返しの雑音を抑える）。phase は 0〜1、step は 1 標本ぶんの進み。"""
    out = 2.0 * phase - 1.0
    head = phase < step
    t = phase[head] / step[head]
    out[head] -= t + t - t * t - 1.0
    tail = phase > 1.0 - step
    t = (phase[tail] - 1.0) / step[tail]
    out[tail] -= t * t + t + t + 1.0
    return out


def render_synth(track, spec, total):
    """少しずつ高さをずらしたノコギリ波の重ね。音の頭でフィルターが開いて閉じ、伸ばす間は明るさがゆっくり揺れる。"""
    from scipy.signal import butter, sosfilt
    n = int(round(total * RATE))
    out = np.zeros((n, 2))
    rng = np.random.default_rng(20261128)
    voices, spread = spec.get("voices", 7), spec.get("spread", 12)
    offsets = np.linspace(-1, 1, voices) if voices > 1 else np.array([0.0])
    stereo = spec.get("stereo", 0.8)
    low = butter(2, spec["low"], "lowpass", fs=RATE, output="sos")
    high = butter(2, spec["high"], "lowpass", fs=RATE, output="sos")
    release = int(0.06 * RATE)
    gl, gr = pan_gains(track.pan)
    for (start, end, pitch, vel) in track.notes:
        a = int(round(start * RATE))
        length = min(int(round((end - start) * RATE)) + release, n - a)
        if length <= 0:
            continue
        local = np.arange(length) / RATE
        cents = step_curve(track.bends, start + local)
        raw = np.zeros((length, 2))
        for v, offset in enumerate(offsets):
            # 声ごとに、ゆっくりした高さのふらつき（±2 セント）を足す。
            drift = 2.0 * np.sin(2 * np.pi * (rng.uniform(0.2, 0.7) * local + rng.uniform()))
            freq = 440.0 * 2.0 ** ((pitch - 69 + (cents + offset * spread + drift) / 100.0) / 12.0)
            step = freq / RATE
            phase = (rng.uniform() + np.cumsum(step)) % 1.0
            wave = saw(phase, step) * (1.0 if offset == 0 else 0.8)
            side = offset * stereo
            raw[:, 0] += wave * np.sqrt(0.5 * (1 - side))
            raw[:, 1] += wave * np.sqrt(0.5 * (1 + side))
        if spec.get("sub"):
            # 基音の正弦波（低音の芯）。1 オクターブ下は、低音の音域では 40 Hz を切って聞こえないので足さない。
            freq = 440.0 * 2.0 ** ((pitch - 69 + cents / 100.0) / 12.0)
            raw += (spec["sub"] * voices * 0.6 * np.sin(2 * np.pi * np.cumsum(freq / RATE)))[:, None]
        dark, bright = sosfilt(low, raw, axis=0), sosfilt(high, raw, axis=0)
        # 明るさ: 音の頭で開いて decay 秒で sustain まで閉じ、そのあとゆっくり揺れる。強い音ほど開く。
        opened = spec["sustain"] + (1 - spec["sustain"]) * np.exp(-local / spec["decay"])
        opened *= 1.0 + 0.25 * np.sin(2 * np.pi * (0.45 * (start + local)))
        opened = np.clip(opened * (0.55 + 0.45 * vel / 127.0), 0, 1)
        piece = dark + opened[:, None] * (bright - dark)
        env = np.minimum(1.0, local / 0.006)
        tail = min(release, length)
        env[-tail:] *= np.linspace(1, 0, tail) ** 2
        env *= step_curve(track.express, start + local) * (vel / 127.0) ** 1.3
        out[a: a + length, 0] += piece[:, 0] * env * gl
        out[a: a + length, 1] += piece[:, 1] * env * gr
    return out / max(1, voices)


# ---------- 混ぜる ----------

def rms(audio):
    return float(np.sqrt(np.mean(audio ** 2)) + 1e-12)


def render_layer(mid, tempo, track, tone, total, work):
    """楽器 1 つ: 音源を鳴らして重ね、整えて、もとの版の大きさに合わせる。返すのは (整えた音, 残響へ送る量)。"""
    reference = render_sf2(mid, tempo, track, None, total, work)
    if tone is None:
        return reference, None
    mixed = np.zeros_like(reference)
    for spec in tone["sources"]:
        if spec["engine"] == "sf2":
            part = render_sf2(mid, tempo, track, spec, total, work)
        elif spec["engine"] == "sampler":
            part = render_sampler(track, spec, total)
        else:
            part = render_synth(track, spec, total)
        if rms(part) < 1e-9:
            continue
        # 重ねる音源どうしは、まず同じ大きさにそろえてから、重ねの比を掛ける。
        mixed += part / rms(part) * spec.get("weight", 1.0)
    mixed = finish.band(mixed, RATE, tone.get("hp"), tone.get("lp"))
    if tone.get("drive"):
        mixed = finish.saturate(mixed, tone["drive"])
    if tone.get("width", 1.0) != 1.0:
        mixed = finish.widen(mixed, tone["width"])
    mixed *= rms(reference) / rms(mixed) * 10 ** (tone.get("trim", 0.0) / 20.0)
    return mixed, tone.get("send", 0.2)


def main():
    args = sys.argv[1:]
    stems = None
    if "--stems" in args:
        i = args.index("--stems")
        stems = args[i + 1]
        del args[i: i + 2]
    if len(args) != 3 or args[1] not in TONES:
        raise SystemExit(f"使い方: tones.py <編曲の MIDI> <{'|'.join(TONES)}> <書き出す WAV> [--stems <場所>]")
    mid, tempo, total, tracks = read_midi(args[0])
    tones = TONES[args[1]]
    n = int(round(total * RATE))
    dry, wet = np.zeros((n, 2)), np.zeros((n, 2))
    if stems:
        os.makedirs(stems, exist_ok=True)
    with tempfile.TemporaryDirectory() as work:
        for track in tracks:
            audio, send = render_layer(mid, tempo, track, tones.get(track.name), total, work)
            if send is None:  # 表に無い楽器。残響は、もとの版の送る量（CC91）に近い量で。
                send = 0.2
            dry += audio
            wet += audio * send
            if stems:
                soundfile.write(os.path.join(stems, track.name + ".wav"), audio, RATE, subtype="FLOAT")
    out = dry + finish.reverb(wet, RATE, BUS["reverb_seconds"]) * BUS["reverb_level"]
    # 全体: 山だけを丸める（決まった高さを基準にする。旋律だけ・伴奏だけを鳴らしたときも、同じ大きさで比べられるように）。
    out = np.tanh(out / BUS["ceiling"]) * BUS["ceiling"]
    soundfile.write(args[2], out, RATE, subtype="FLOAT")


if __name__ == "__main__":
    main()
