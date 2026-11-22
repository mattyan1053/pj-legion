# 駒のアイコン

- 出どころ: **スクリプトで生成**（`tools/unit_icons.sh` → `tools/unit_icons.gd`）。駒の 3D の形（駒の見た目の組 `kaykit`（`game/looks/kaykit_look.gd`）が組む形と持ち物、陣営の色、進化の金の輪）を、正面から写して 96×96 の PNG にしたもの。絵は描いていない。
- 元の素材（組 `kaykit`）: KayKit : Adventurers Character Pack 1.0 と KayKit Character Pack : Skeletons 1.0（Kay Lousberg、CC0 1.0。`assets/kaykit/adventurers/`、`assets/kaykit/skeletons/`）。中立の駒は、素材を使わずコードで組んだ形。
- ライセンス: 元の素材と同じ CC0 1.0（`LICENSE.txt`）。

ファイル名は `<種類>_<陣営>[_evolved].png`（陣営は `blue`・`red`・`neutral`）。名前のある人物の形（`game/unit_looks.gd` の `PERSONS`。組 `kaykit` と `kaykit2` だけ）は `person_<人物>_<陣営>[_evolved].png`。読み出すのは `game/unit_icons.gd`。
ここに直に置いてあるのは組 `kaykit` の絵。`tokens/` は組 `tokens`（コードで組んだ形。元の素材なし）、
`quaternius/` は組 `quaternius`（Quaternius の CC0 の素材。`assets/quaternius/`）の絵、
`mini/` は組 `mini`（Kenney の CC0 の素材。`assets/kenney/mini-characters/`）の絵、
`kaykit2/` は組 `kaykit2`（KayKit の CC0 の素材。`assets/kaykit/adventurers2/`。魔物は `assets/kaykit/skeletons/`）の絵。ほかの組の絵は、組の定義の `icon_dir`（このディレクトリの下の、組の名前のディレクトリ）に置く。
駒の形や陣営の色を変えたら、`tools/unit_icons.sh <godot> [組の名前]` で書き直す（画面の描画が要るので、画面の無いコンテナでは Xvfb の上で回す）。
