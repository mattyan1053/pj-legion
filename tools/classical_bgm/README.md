# クラシックの編曲の BGM を作る道具

楽譜のデータ（作曲の権利が切れた曲の、ライセンスのはっきりした打ち込み）から、編曲・音の書き出し・ループの整えまでを 1 本で回す。
出来たものと、その出どころ・ライセンスは `assets/audio/classical/README.md`。

    tools/classical_bgm/build.sh [書き出す先（既定: assets/audio/classical）]

## 要るもの

- `apt install lilypond fluidsynth fluid-soundfont-gm ffmpeg`（LilyPond 2.24、サウンドフォント FluidR3_GM（MIT））
- `pip install mido numpy soundfile pyloudnorm`
- 別のサウンドフォントを使うなら `SF2=<パス>`。**作った音を再配布できるライセンスのものに限る**（MIT・CC0 など）。サウンドフォントはリポジトリに入れない

## 手順（build.sh の中身）

1. `winter/`（「冬」第 1 楽章）と `summer/`（「夏」第 3 楽章）の楽譜（Mutopia の LilyPond 2.12 の原稿。手を入れずに置いてある）を作業用の場所へ写し、
   `convert-ly` で 2.24 の書き方に直す（「夏」の頭の `old-relative` は 2.24 に無いので消す。和音は `\relative` の外にだけあるので、音の高さは変わらない）。
2. `*-midi.ly` で、パートごと（独奏・第 1・第 2 ヴァイオリン・ヴィオラ・チェロ）の MIDI にする。`articulate.ly` がトリルを音に書き下す。
3. `arrange.py` が版ごとに編曲する（`VERSIONS`）。原曲を頭から流さず、戦闘曲の型に組み直す:
   - `form`: 鳴らす小節のまとまり（区切り）の並びと、区切りごとの強さの段（1〜3）。同じ小節を何度並べてもよい。並びの終わりから頭へループする。
   - 弦は短く切り、伸ばす音は `grid`（8 分か 16 分）で刻み直す。弱い所を作らない（どの小節も f）。
   - 足す層（低音のオスティナート、ティンパニ、打楽器かドラムキット、金管の打ち込み、パッド、重ねる旋律、歪んだギター）は、楽譜の拍ごとの和声（根音と和音）から機械的に作る。
     区切りの頭にシンバル、終わりの拍にフィル。
   - `dark`（濁り）と `hits`（スタッカートの「ダダダンッ」と溜め）は、区切りの頭と終わりにだけ足す（管2・電2）。`arrange.py` の頭の説明と `assets/audio/classical/README.md`。
   - ループの終わりのあとに 2 小節の間を置き、残響の尾まで録れるようにする。
4. FluidSynth で WAV にする（44.1 kHz、残響あり、コーラスなし）。
5. `finish.py` が、ループの長さで切って尾を頭に重ね、-16 LUFS（ピークは -1 dBFS まで）にそろえて Ogg Vorbis（品質 4）にし、測った値を出す。

6. 「圧」の物差しは `measure.py <ogg>...`（低域の割合、立ち上がりの強さ、大きさの幅と谷、頭の強さ。`assets/audio/classical/README.md` の「圧の物差し」）。

同じ道具とサウンドフォントなら、同じ音が出来る（ogg を戻した音で確かめた。ogg のファイルそのものは、ストリームの通し番号が毎回変わるので一致しない）。
`assets/audio/classical/winter_heavy.ogg`（前の版。比べ用）は、いまの `build.sh` では作らない（コミット 91abfae の道具で作った）。

## 版を足す・変える

- 版は `arrange.py` の `VERSIONS`。楽器の音色・大きさ・左右は `CHANNELS`（チャンネルは版ごとに使う楽器にだけ割り当てる。打楽器のほかに 15 まで）。
- 拍子は曲ごと（`PIECES`）。
- 別の曲を足すなら、楽譜を `<曲>/` に置き（ライセンスの文を付ける）、パートの名前を合わせた `*-midi.ly` を書いて、`build.sh` に足す。
  楽譜のデータのライセンスは、打ち込んだ人のもの（Public Domain・CC0 を優先。CC BY-SA なら、作った音も CC BY-SA になる）。
- 曲を差し替えたら、`assets/audio/classical/README.md` の表と測り、`game/sound_catalog.gd` の `volume_db` を直す。
- 楽譜の小節の中身（パートごとの音の数と音域）を見るときは、`arrange.py` の `read_parts` で MIDI を読んで小節ごとに数える。
