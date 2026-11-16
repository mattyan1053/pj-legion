# Zen Kaku Gothic New / Zen Old Mincho（UI の文字）

- 作者: 大平善道（Yoshimichi Ohira）、The Zen Kaku Gothic Project Authors / The Zen Old Mincho Project Authors
- 入手元: Google Fonts のリポジトリ（https://github.com/google/fonts の `ofl/zenkakugothicnew/` と `ofl/zenoldmincho/`。
  main ブランチ、取ってきた日のコミットは 7af0d90）
  - 元のリポジトリ: https://github.com/googlefonts/zen-kakugothic 、https://github.com/googlefonts/zen-oldmincho
- ライセンス: SIL Open Font License 1.1（`LICENSE-ZenKakuGothicNew.txt`、`LICENSE-ZenOldMincho.txt`。配布元の `OFL.txt` をそのまま写した）。
  ゲームに同梱しての再配布ができる。フォントだけを売ることはできない。Reserved Font Name の指定は無い
  - CC0 ではない。OFL が求めるのは、著作権の表示とライセンスの文を一緒に配ること（この 2 つの `LICENSE-*.txt` がそれ）。
    ゲームの画面にクレジットを出すことは求められていない
- 取ってきた日・ライセンスを確かめた日: 2026-11-16（配布元の `OFL.txt` と、各ディレクトリの `METADATA.pb` の `license: "OFL"`）
- 改変: なし（配布元の TTF のまま。ファイル名も元のまま）

| ファイル | 使う所（`game/ui_theme.gd`） |
| --- | --- |
| `ZenKakuGothicNew-Medium.ttf` | 本文（既定の文字）。日本語と欧文 |
| `ZenKakuGothicNew-Bold.ttf` | 小見出しと、いちばん大事なボタン |
| `ZenOldMincho-Bold.ttf` | 題字と、画面の見出し |

フォントに無い字（一部の記号など）は、Godot が動かしている OS の文字で補う。
ウェイトを足すときは、同じ配布元から取って、この表に書き足す。
