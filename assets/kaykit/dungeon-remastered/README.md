# KayKit : Dungeon Remastered 1.0

- 作者: Kay Lousberg（https://www.kaylousberg.com）
- 入手元: https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0 （`main`、コミット `b0ca9bd`、`addons/kaykit_dungeon_remastered/Assets/gltf/`）
- ライセンス: CC0 1.0（`LICENSE.txt`）。商用・改変・再配布が自由で、クレジット表記は任意
- 確かめた日: 2026-11-16
- 入れたもの（**中身は無改変**。名前の `.gltf.glb` を `.glb` に縮めただけ）:
  - `pillar` / `wall` / `wall_broken`: 迷宮回廊の障害物のマス（石の柱と、柱どうしをつなぐ壁）
  - `wall_broken` / `wall_half` / `column` / `rubble_large` / `rubble_half` / `barrier_column`: 迷宮回廊の盤の外の、崩れた石組み
  - `sword_shield_broken`（折れた剣と盾）: 古戦場の盤の外に、土に刺さった形で置く（2026-11-21 に足した。コミットは同じ `b0ca9bd`）
  - `*_dungeon_texture.png`: 各 `.glb` に埋め込まれたテクスチャを、Godot の取り込みが書き出したもの（中身はどれも同じ `dungeon_texture.png`）

どこにどう置くかは `game/stage_look.gd`（マップの見た目）で決めている。
