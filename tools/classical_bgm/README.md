# クラシックの編曲の BGM を作る道具

楽譜のデータ（作曲の権利が切れた曲の、ライセンスのはっきりした打ち込み）から、編曲・音の書き出し・ループの整えまでを 1 本で回す。
出来たものと、その出どころ・ライセンスは `assets/audio/classical/README.md`。

    tools/classical_bgm/build.sh [書き出す先（既定: assets/audio/classical）]

## 要るもの

- `apt install lilypond fluidsynth fluid-soundfont-gm ffmpeg`（LilyPond 2.24、サウンドフォント FluidR3_GM（MIT））
- `pip install mido numpy scipy soundfile pyloudnorm`
- 別のサウンドフォントを使うなら `SF2=<パス>`。**作った音を再配布できるライセンスのものに限る**（MIT・CC0 など）。サウンドフォントはリポジトリに入れない
- 音色の組で鳴らす版（新重・新電。下の「音色の組」）には、さらに 3 つの音源が要る。どれもリポジトリに入れない。場所は環境変数で渡す:
  - `apt install musescore-general-soundfont-lossless`（MuseScore_General_Full.sf2、MIT。`SF2_MUSESCORE`）
  - `apt install avldrums.lv2-soundfont`（AVL Drumkits の Red_Zeppelin_4_LV2.sf2、CC BY-SA 3.0。`SF2_DRUMS`）
  - VSCO 2 CE（CC0。`VSCO=<置いた場所>`）。使うフォルダだけ取ればよい（300MB ほど）:

        git clone --filter=blob:none --no-checkout https://github.com/sgossner/VSCO-2-CE.git vsco && cd vsco
        git sparse-checkout init --no-cone
        printf '%s\n' '/LICENSE' '/Strings/Solo Violin/Arco Vib/' '/Strings/Solo Violin/spic/' '/Brass/Tenor Trombone/' \
          '/Brass/Tuba/' '/Strings/Cello Section/spic/' '/Strings/Cello Section/susvib/' > .git/info/sparse-checkout
        git checkout master    # 確かめたコミット: 440300901dfe9275fd84e0b7763af1f8443ae62e

## 手順（build.sh の中身）

1. `winter/`（「冬」第 1 楽章）と `summer/`（「夏」第 3 楽章）の楽譜（Mutopia の LilyPond 2.12 の原稿。手を入れずに置いてある）を作業用の場所へ写し、
   `convert-ly` で 2.24 の書き方に直す（「夏」の頭の `old-relative` は 2.24 に無いので消す。和音は `\relative` の外にだけあるので、音の高さは変わらない）。
2. `*-midi.ly` で、パートごと（独奏・第 1・第 2 ヴァイオリン・ヴィオラ・チェロ）の MIDI にする。`articulate.ly` がトリルを音に書き下す。
3. `arrange.py` が版ごとに編曲する（`VERSIONS`）。作りは 3 つある:
   - **暗く重い版**（`"dark_arrangement": True`。中身は `dark.py`。暗重・暗電。暗中は `VERSIONS` に残してあるが、いまは作らない）: 区切りに役（low / solo / build / mid / peak）を付ける。
     伸ばす音には揺れ（`Score.shape`。遅れて掛かるビブラート = ピッチベンド、強さの動き = CC11、2 つの音色を数セントずらす）。低音・ギター・弦は伸ばさずに刻む。
     リードは旋律の 1 オクターブ下。動機は全部の層がユニゾンで 1 音ずつ区切って打つ（`strike_motif`。`motif` で 32 分のまま / 16 分 3 つに間引く / 低い層だけ 32 分）。
   - **緩急つきの版**（`"wave": True`。中身は `swell.py`。電重。`VERSIONS` に残してあるが、いまは作らない）: 原曲の流れに沿って、区切りに役（calm / solo / build / mid / peak）を付ける。
     役ごとに、弦の強さ、低音・ギター・ドラムの型が変わる。主旋律（`melody_line`）を独奏とリードで前に出す。
     盛り上がりの動機（16 分 + 32 分 6 つ + 16 分 4 つ。`motif_halves`）は、ドラムとギターが旋律と同じリズムで打つ。
     区切りの終わりに、その小節の旋律に合わせた強打の型（`FIGURES`・`BAR_FIGURES`。終わりのあとの 1 拍目にシンバル）。`dark` で区切りの頭に濁り。`mix` で楽器の音量。
   - **前の版**（電2・重・夏）: 強い所だけを小節で切り出して並べ（`form` の 3 つ目は強さの段 1〜3）、どの小節も f。
     足す層は、楽譜の拍ごとの和声から機械的に作る。`dark`（濁り）と `hits`（3 拍目の裏からの「ダダダンッ」と無音）は電2 だけ。
   - どちらも、ループの終わりのあとに 2 小節の間を置き、残響の尾まで録れるようにする。
     測り用に、旋律だけ・伴奏だけの MIDI（`*.melody.mid`・`*.backing.mid`）、区切りの秒数（`*.mid.sections`）、動機の始まる秒（`*.mid.motifs`）も書く。
4. FluidSynth で WAV にする（44.1 kHz、残響あり、コーラスなし）。音色の組で鳴らす版は、`tones.py` が楽器ごとに音源を選んで鳴らす（下の「音色の組」）。
5. `finish.py` が、ループの長さで切って尾を頭に重ね、-16 LUFS（ピークは -1 dBFS まで）にそろえて Ogg Vorbis（品質 4）にし、測った値を出す。
   緩急つきの版と暗く重い版は、強い所の山がつかえたら、-1 dBFS を超える山だけを抑えて上げる（`limit`）。
   この 2 つは続けて `sections.py` が、区切りごとの大きさ・密度と、旋律と伴奏の大きさの差を出す（`MEASURE=1` なら、ほかの版も）。

6. 物差しは `measure.py`（測り方はスクリプトの頭。どれが耳と合ったかは `assets/audio/classical/README.md` の「物差しは、良い版とだめな版を分けられるか」）:
   - `measure.py <ogg>...`: 圧（低域の割合、立ち上がりの強さ、大きさの幅と谷、頭の強さ）と明るさ（2 kHz 以上 ÷ 200 Hz 未満）。
   - `measure.py --motif <WAV> <.motifs>...`: 動機の所の打ち方（「タンッ」の立ち上がりと隙間、走る音の明るさと低い所の刻み）。
   - `measure.py --wobble <MIDI>...`: 伸ばす音の揺れ（楽器ごとに書き出して、高さと大きさの揺れ、止まった音の長さ）。
   `WORK=<場所>` を付けて `build.sh` を回すと、途中の MIDI と WAV がそこに残る（付けなければ消える）。

## 音色の組（`tones.py`。楽器ごとに音源を選ぶ）

編曲（音符）はそのままで、音色と仕上げだけを替えた版を作る仕組み。`arrange.py` の `VERSIONS` で `"tone"`（音色の組の名前）と `"same_as"`（同じ編曲のもとの版）を持つ版がそれ。
`build.sh` は、その版の MIDI がもとの版と 1 バイトも違わないことを確かめてから（`cmp`）、`tones.py` に渡す。

- `tones.py` の `TONES`（音色の組 → 楽器 → 設定）が、楽器（`CHANNELS` の名前 = MIDI のトラック）ごとに、鳴らす音源（1 つか、重ねる 2〜3 つ）と整え方を決める。
  表に無い楽器は、もとのまま（FluidR3_GM）で鳴る。
- 音源の種類は 3 つ:
  - `sf2`: サウンドフォントを FluidSynth で鳴らす（どのサウンドフォントのどの音色か、鍵の範囲、数セントのずらし、左右、遅らせ）。
  - `sampler`: 録った音（1 音 1 ファイルの WAV）を、音の高さに合わせて鳴らす。短い音と長い音で別の録音（スタッカートと伸ばし）を使う。ビブラート（ピッチベンド）と強さ（CC11）にも従う。
  - `synth`: スクリプトで作るシンセ（少しずつ高さをずらしたノコギリ波の重ね。音の頭でフィルターが開いて閉じ、伸ばす間は明るさがゆっくり揺れる）。音源のファイルは要らない。
- 整え方（中身は `finish.py`）: 帯域（`hp`・`lp`。楽器どうしが同じ帯域でぶつからないように）、あとから掛ける歪み（`drive`）、左右の広がり（`width`）、残響へ送る量（`send`）。
  残響は FluidSynth のものを使わず、全部の楽器を 1 つの残響（`finish.reverb`。左右で別の、減っていく雑音の畳み込み。250 Hz より下は残さない）に送る。
- **音量の釣り合いは変えない**: 楽器ごとに、もとの版（FluidR3_GM で鳴らした同じトラック）の大きさ（RMS）に合わせてから混ぜる。音源を替えても、編曲で決めた釣り合いが崩れない。
- `--stems <場所>` で、楽器ごとの音を残す。`STEMS=<場所> measure.py --wobble <MIDI>` で、その音の伸ばす音の揺れを測る。
- 音色の組を足すなら `TONES` に 1 つ足し、`VERSIONS` に `dict(VERSIONS["<もとの版>"], tone="<組>", same_as="<もとの版>")` を足して、`build.sh` の版の並びに入れる。
  **使う音源は、作った音を配れるライセンスのものに限り**、出どころを `assets/audio/classical/README.md` に書く。

同じ道具とサウンドフォントなら、同じ音が出来る（ogg を戻した音で確かめた。ogg のファイルそのものは、ストリームの通し番号が毎回変わるので一致しない）。

## 版を足す・変える

- 版は `arrange.py` の `VERSIONS`。楽器の音色・大きさ・左右は `CHANNELS`（チャンネルは版ごとに使う楽器にだけ割り当てる。打楽器のほかに 15 まで）。
- 拍子は曲ごと（`PIECES`）。
- 別の曲を足すなら、楽譜を `<曲>/` に置き（ライセンスの文を付ける）、パートの名前を合わせた `*-midi.ly` を書いて、`build.sh` に足す。
  楽譜のデータのライセンスは、打ち込んだ人のもの（Public Domain・CC0 を優先。CC BY-SA なら、作った音も CC BY-SA になる）。
- 曲を差し替えたら、`assets/audio/classical/README.md` の表と測り、`game/sound_catalog.gd` の `volume_db` を直す。
- 楽譜の小節の中身（パートごとの音の数と音域）を見るときは、`arrange.py` の `read_parts` で MIDI を読んで小節ごとに数える。
