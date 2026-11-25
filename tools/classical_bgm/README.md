# クラシックの編曲の BGM を作る道具

楽譜のデータ（作曲の権利が切れた曲の、ライセンスのはっきりした打ち込み）から、編曲・音の書き出し・ループの整えまでを 1 本で回す。
出来たものと、その出どころ・ライセンスは `assets/audio/classical/README.md`。

    tools/classical_bgm/build.sh [書き出す先（既定: assets/audio/classical）]

## 要るもの

- `apt install lilypond fluidsynth fluid-soundfont-gm ffmpeg`（LilyPond 2.24、サウンドフォント FluidR3_GM（MIT））
- `pip install mido numpy soundfile pyloudnorm`
- 別のサウンドフォントを使うなら `SF2=<パス>`。**作った音を再配布できるライセンスのものに限る**（MIT・CC0 など）。サウンドフォントはリポジトリに入れない

## 手順（build.sh の中身）

1. `winter/` の楽譜（Mutopia の LilyPond 2.12 の原稿。手を入れずに置いてある）を作業用の場所へ写し、`convert-ly` で 2.24 の書き方に直す。
2. `winter/winter1-midi.ly` で、パートごと（独奏・第 1・第 2 ヴァイオリン・ヴィオラ・チェロ）の MIDI にする。`articulate.ly` がトリルを音に書き下す。
3. `arrange.py` が版ごとに編曲する（`VERSIONS`: テンポ、鳴らす小節、足す楽器）。全合奏の小節は f、独奏の小節の伴奏は p。
   足す楽器（コントラバス、チェンバロ、ティンパニ、トロンボーンとチューバ、ホルン、合唱）は、楽譜の低音と内声から機械的に作る。
   ループの終わりのあとに 2 小節の間を置き、残響の尾まで録れるようにする。
4. FluidSynth で WAV にする（44.1 kHz、残響あり、コーラスなし）。
5. `finish.py` が、ループの長さで切って尾を頭に重ね、-16 LUFS（ピークは -1 dBFS まで）にそろえて Ogg Vorbis（品質 4）にし、測った値を出す。

同じ道具とサウンドフォントなら、同じ ogg が出来る（確かめた）。

## 版を足す・変える

- 版は `arrange.py` の `VERSIONS`。楽器の音色・大きさ・左右は `CHANNELS`。
- 別の曲を足すなら、楽譜を `<曲>/` に置き（ライセンスの文を付ける）、パートの名前を合わせた `*-midi.ly` を書いて、`build.sh` に足す。
  楽譜のデータのライセンスは、打ち込んだ人のもの（Public Domain・CC0 を優先。CC BY-SA なら、作った音も CC BY-SA になる）。
- 曲を差し替えたら、`assets/audio/classical/README.md` の表と測り、`game/sound_catalog.gd` の `volume_db` を直す。
