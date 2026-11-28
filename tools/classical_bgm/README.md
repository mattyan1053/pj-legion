# クラシックの編曲の BGM を作る道具

楽譜のデータ（作曲の権利が切れた曲の、ライセンスのはっきりした打ち込み）から、編曲・音の書き出し・ループの整えまでを 1 本で回す。
出来たものと、その出どころ・ライセンスは `assets/audio/classical/README.md`。

    tools/classical_bgm/build.sh [書き出す先（既定: assets/audio/classical）]

## 要るもの

- `apt install lilypond fluidsynth fluid-soundfont-gm ffmpeg`（LilyPond 2.24、サウンドフォント FluidR3_GM（MIT））
- `pip install mido numpy scipy soundfile pyloudnorm`
- 別のサウンドフォントを使うなら `SF2=<パス>`。**作った音を再配布できるライセンスのものに限る**（MIT・CC0 など）。サウンドフォントはリポジトリに入れない

## 手順（build.sh の中身）

1. `winter/`（「冬」第 1 楽章）と `summer/`（「夏」第 3 楽章）の楽譜（Mutopia の LilyPond 2.12 の原稿。手を入れずに置いてある）を作業用の場所へ写し、
   `convert-ly` で 2.24 の書き方に直す（「夏」の頭の `old-relative` は 2.24 に無いので消す。和音は `\relative` の外にだけあるので、音の高さは変わらない）。
2. `*-midi.ly` で、パートごと（独奏・第 1・第 2 ヴァイオリン・ヴィオラ・チェロ）の MIDI にする。`articulate.ly` がトリルを音に書き下す。
3. `arrange.py` が版ごとに編曲する（`VERSIONS`）。作りは 2 つある:
   - **緩急つきの版**（`"wave": True`。中身は `swell.py`。電重・電中・電全）: 原曲の流れに沿って、区切りに役（calm / solo / build / mid / peak）を付ける。
     役ごとに、弦の強さ、低音・ギター・ドラムの型が変わる。主旋律（`melody_line`）を独奏とリードで前に出す。
     盛り上がりの動機（16 分 + 32 分 6 つ + 16 分 4 つ。`motif_halves`）は、ドラムとギターが旋律と同じリズムで打つ。
     区切りの終わりに、その小節の旋律に合わせた強打の型（`FIGURES`・`BAR_FIGURES`。終わりのあとの 1 拍目にシンバル）。`dark` で区切りの頭に濁り。`mix` で楽器の音量。
   - **前の版**（電2・重・夏）: 強い所だけを小節で切り出して並べ（`form` の 3 つ目は強さの段 1〜3）、どの小節も f。
     足す層は、楽譜の拍ごとの和声から機械的に作る。`dark`（濁り）と `hits`（3 拍目の裏からの「ダダダンッ」と無音）は電2 だけ。
   - どちらも、ループの終わりのあとに 2 小節の間を置き、残響の尾まで録れるようにする。
     測り用に、旋律だけ・伴奏だけの MIDI（`*.melody.mid`・`*.backing.mid`）と、区切りの秒数（`*.mid.sections`）も書く。
4. FluidSynth で WAV にする（44.1 kHz、残響あり、コーラスなし）。
5. `finish.py` が、ループの長さで切って尾を頭に重ね、-16 LUFS（ピークは -1 dBFS まで）にそろえて Ogg Vorbis（品質 4）にし、測った値を出す。
   緩急つきの版は、強い所の山がつかえるので、-1 dBFS を超える山だけを抑えて上げる（`limit`）。
   緩急つきの版は続けて `sections.py` が、区切りごとの大きさ・密度と、旋律と伴奏の大きさの差を出す（`MEASURE=1` なら、ほかの版も）。

6. 「圧」の物差しは `measure.py <ogg>...`（低域の割合、立ち上がりの強さ、大きさの幅と谷、頭の強さ。`assets/audio/classical/README.md` の「圧の物差し」）。

同じ道具とサウンドフォントなら、同じ音が出来る（ogg を戻した音で確かめた。ogg のファイルそのものは、ストリームの通し番号が毎回変わるので一致しない）。

## 版を足す・変える

- 版は `arrange.py` の `VERSIONS`。楽器の音色・大きさ・左右は `CHANNELS`（チャンネルは版ごとに使う楽器にだけ割り当てる。打楽器のほかに 15 まで）。
- 拍子は曲ごと（`PIECES`）。
- 別の曲を足すなら、楽譜を `<曲>/` に置き（ライセンスの文を付ける）、パートの名前を合わせた `*-midi.ly` を書いて、`build.sh` に足す。
  楽譜のデータのライセンスは、打ち込んだ人のもの（Public Domain・CC0 を優先。CC BY-SA なら、作った音も CC BY-SA になる）。
- 曲を差し替えたら、`assets/audio/classical/README.md` の表と測り、`game/sound_catalog.gd` の `volume_db` を直す。
- 楽譜の小節の中身（パートごとの音の数と音域）を見るときは、`arrange.py` の `read_parts` で MIDI を読んで小節ごとに数える。
