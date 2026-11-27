# クレジット

コード: `game/credits.csv`（表）、`game/credits.gd`（表を読む。ノードに依存しない）、`game/credits_panel.gd`（タイトルの「クレジット」の窓）、
`addons/credits_export/`（書き出しのときに、exe の隣へ `CREDITS.txt` と `licenses/` を書く）。テスト: `tests/game/test_credits.gd`。

入れた素材の名前・作者・出どころ・ライセンスを、ゲームの中と、書き出しに添える文書で見せる（Issue #46 の 11/26「クレジット画面を足すでもいいか」から）。
CC0 の素材も、礼として載せる。**画面と文書は同じ 1 つの表から作る**（手で二重に持たない）。素材の詳しい記録（取ってきた日、改変、ファイルごとの使い道）は、
いままでどおり `assets/<出どころ>/README.md` に置き、表には画面に出す 6 つの列だけを置く。

## 表（`game/credits.csv`）

1 行 1 素材（パック・曲・フォントの単位）で `group,name,author,source,license,license_file`。

| 列 | 中身 |
| --- | --- |
| `group` | 種類。`font`（フォント）、`unit`（兵と魔物）、`board`（盤）、`sound`（音。曲も効果音も）。画面と文書は、この順の見出しで並べる（`Credits.GROUPS`） |
| `name` | 素材名（配布元の題のまま。英語なら英語のまま） |
| `author` | 作者（配布元の表記のまま。まとめた人と元の作者が違えば両方） |
| `source` | 出どころの URL |
| `license` | ライセンスの名前（「CC0 1.0」「SIL Open Font License 1.1」など） |
| `license_file` | リポジトリの中のライセンスの文（`assets/.../LICENSE*.txt`） |

検査（`test_credits.gd`）: どの列も空でない、ライセンスの文がある、`assets/` のライセンスの文（`LICENSE*`）がどれも表のどこかの行から指されている
（スクリプトで作った `assets/unit_icons/` は除く）。表に載せ忘れた素材を入れると落ちる。

## 表記の要る素材を入れるとき

CC BY・CC BY-SA など、クレジットの表記を求めるライセンスの素材を入れるときは、**この表に 1 行足す**。それで、タイトルのクレジットの窓と、
書き出しに添える `CREDITS.txt` の両方に出る。ライセンスの文の同梱を求めるもの（SIL OFL など）は、`credits_panel.gd` の `SHOWN_LICENSES` にライセンスの名前を足すと、窓に文がそのまま載る。
入れ方の残りは `add-asset`（`.claude/skills/add-asset/SKILL.md`）。表記の求める形（作者名、題、URL、ライセンスの名前と URL、改変したか）が表の列で足りないライセンスなら、列を足す。

## 画面（タイトルの「クレジット」）

- タイトルのメニュー（ストーリー・対戦・オプション・**クレジット**・終了）から開く重なる窓。決まった大きさ（`CreditsPanel.SIZE`）で、中身は窓の中で送る。
- 上から、礼の 1 行、種類ごとの見出しと、素材ごとに「名前（太字）　ライセンス（金）」・作者・出どころ（URL）。最後に、SIL OFL のフォントのライセンスの文をそのまま。
- 「閉じる」・右クリック・Esc・窓の外のクリックで閉じる。

## 書き出し

- exe の中: 表（`game/credits.csv`）と、`assets/` の下のライセンスの文（`LICENSE*`）を入れる（`export_presets.cfg` の `include_filter`）。窓はこれを読む。
- exe の隣: 書き出すと、`addons/credits_export/` の書き出しの手（`EditorExportPlugin`。`project.godot` の `editor_plugins` で有効）が、
  書き出した先のフォルダに `CREDITS.txt`（表から作った一覧）と `licenses/`（表に出てくるライセンスの文）を書く。
- CI の成果物（`pj-legion-windows`）に入れるには、ワークフロー（`.github/workflows/build.yml`）の `upload-artifact` の `path` を
  `build/pj-legion.exe` から `build/` にする必要がある（ワークフローは作業のセッションでは変えないので、人間に頼む）。
