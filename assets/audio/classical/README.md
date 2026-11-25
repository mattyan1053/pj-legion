# クラシックの編曲（楽譜のデータから、スクリプトで作った曲）

オプションの「BGM の組」の「クラシック 1〜3」で鳴る曲（`game/sound_catalog.gd` の `MUSIC_SETS`）。既定（いまの組）では鳴らない。
**曲は聴いていない。** 下の測りだけで確かめた。

- 曲: アントニオ・ヴィヴァルディ「四季」より「冬」（L'Inverno、協奏曲 Op. 8 No. 4、RV 297）第 1 楽章 Allegro non molto。作曲は 1725 年ごろで、作曲の権利は無い
- 楽譜のデータ: Mutopia Project の LilyPond の原稿（Mutopia-2010/02/08-351。浄書は「Anonymous」、底本は Performers' Facsimiles）
  - 取ってきた所: https://github.com/MutopiaProject/MutopiaProject/tree/2144afd6f52d56c5b6995b8b589ef1268b3139f0/ftp/VivaldiA/O8/winter/winter-lys
  - ライセンス: **CC BY-SA 3.0 Unported**（原稿の `winter-header.ly` の `copyright` と、楽譜に刷られる文）。
    Mutopia のサイト（mutopiaproject.org）は、この環境からは開けない。GitHub の原稿のヘッダで確かめた
  - 取ってきた日・ライセンスを確かめた日: 2026-11-25
  - 原稿はそのまま `tools/classical_bgm/winter/` に置いた（`LICENSE.txt` 付き）
- 音色: サウンドフォント FluidR3_GM（Frank Wen。**MIT**。Debian / Ubuntu の `fluid-soundfont-gm` の `copyright` の条文を 2026-11-25 に確かめた）。
  サウンドフォントはリポジトリに入れていない（140MB あまり）。作った音の再配布は MIT の範囲（`LICENSE.txt` に条文を写した）
- **この曲のライセンス: CC BY-SA 3.0**（楽譜のデータの改変物として、同じ条件で出す。`LICENSE.txt`）。
  表記（Mutopia Project、浄書者、ライセンス）が要る。ゲームの中にクレジットの画面はまだ無い。
  表記とライセンスの文（`LICENSE.txt`）は、`export_presets.cfg` の `include_filter` で exe にも入れる
- 作り方: `tools/classical_bgm/build.sh`（`README.md`）。楽譜 → LilyPond で MIDI → `arrange.py` で編曲 → FluidSynth で音 → `finish.py` でループと大きさ → Ogg Vorbis（品質 4）

| ファイル | 組（オプション） | 版 | テンポ | 小節 | 長さ |
| --- | --- | --- | --- | --- | --- |
| `winter_strings.ogg` | クラシック 1 | 原曲に近い形: 独奏ヴァイオリン、弦の合奏、チェロ、コントラバス、チェンバロ（通奏低音） | ♩=104 | 全 63 小節 | 2:25 |
| `winter_boss.ogg` | クラシック 2 | ボス戦の形: 上に、ティンパニ・トロンボーンとチューバ・ホルン（全合奏の小節）、終わりの合奏に合唱。チェンバロは抜く | ♩=112 | 全 63 小節 | 2:15 |
| `winter_heavy.ogg` | クラシック 3 | 重い形: テンポを落とし、ティンパニ・低音の金管・合唱（全合奏の小節）。ホルンとチェンバロは抜く | ♩=80 | 1〜26 と 56〜63 小節（中ほどの独奏を抜く） | 1:42 |

どの組でも、終盤（`battle_climax`）・中ボス（`battle_boss`）・物語の終わりの 2 話（`battle_eve`・`battle_last`）・締めの話の終盤（`battle_final`）に当てる。
大きさは、書き出しで -16 LUFS にそろえ、`volume_db` を -5.5（対戦のねらい -21.5 LUFS との差）にした。

## 測り（耳では確かめていない）

`finish.py` が出す値（ogg にしたあとで測り直した値も、ほぼ同じ）。

| ファイル | 積分ラウドネス | ピーク | つなぎ目の段差 | スペクトルの重心 | 150 Hz 未満の割合 |
| --- | --- | --- | --- | --- | --- |
| `winter_strings.ogg` | -16.0 LUFS | -2.1 dBFS | 0.01（ogg で 0.03） | 2173 Hz | 10.6% |
| `winter_boss.ogg` | -16.0 LUFS | -2.1 dBFS | 0.20（ogg で 0.37） | 1799 Hz | 8.6% |
| `winter_heavy.ogg` | -16.0 LUFS | -2.3 dBFS | 0.10（ogg で 0.19） | 1689 Hz | 15.8% |

- つなぎ目の段差: 終わりと頭の標本の差を、曲全体の隣り合う標本の差の 99.5 パーセンタイルと比べた比（`oga-bgm-sets/README.md` と同じ測り方）。1 未満なら、ふだんの差に紛れる。
  ループは小節の切れ目ちょうど（拍の数 × 60 / テンポ）で切り、ループの終わりより後の残響を頭に重ねた。
- 曲の頭（1〜4 小節）は、原曲どおりチェロだけから始まり、パートが 1 つずつ重なって大きくなる（ボス戦と重い形は、ティンパニの 8 分音符も重ねる）。
  終わりの小節は、主和音を 1 拍鳴らしたあとの 3 拍の間。ボス戦と重い形は、そこにティンパニの連打（属音）を置いて頭へつなぐ。
- 楽器はどれも生楽器のサンプル（GM の音色の弦・金管・ティンパニ・チェンバロ・合唱）。シンセやビット音源の音色は使っていない。
