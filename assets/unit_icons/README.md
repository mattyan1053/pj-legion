# 駒のアイコン

- 出どころ: **スクリプトで生成**（`tools/unit_icons.sh` → `tools/unit_icons.gd`）。駒の 3D の形（`game/unit_view.gd` が組む形と持ち物、陣営の色、進化の金の輪）を、正面から写して 96×96 の PNG にしたもの。絵は描いていない。
- 元の素材: KayKit : Adventurers Character Pack 1.0（Kay Lousberg、CC0 1.0。`assets/kaykit/adventurers/`）。中立の駒は、素材を使わずコードで組んだ形。
- ライセンス: 元の素材と同じ CC0 1.0（`LICENSE.txt`）。

ファイル名は `<種類>_<陣営>[_evolved].png`（陣営は `blue`・`red`・`neutral`）。読み出すのは `game/unit_icons.gd`。
駒の形や陣営の色を変えたら、`tools/unit_icons.sh <godot>` で書き直す（画面の描画が要るので、画面の無いコンテナでは Xvfb の上で回す）。
