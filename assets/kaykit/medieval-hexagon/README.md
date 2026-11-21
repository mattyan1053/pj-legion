# KayKit : Medieval Hexagon Pack 1.0

- 作者: Kay Lousberg（https://www.kaylousberg.com）
- 入手元: https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0 （`main`、`addons/kaykit_medieval_hexagon_pack/Assets/gltf/decoration/nature/`）
- ライセンス: CC0 1.0（`LICENSE.txt`）。商用・改変・再配布が自由で、クレジット表記は任意
- 入れたもの（**無改変**）:
  - `trees_A_small` / `trees_B_small`（`.gltf` + `.bin`）: 森のマスの木立
  - `mountain_A`（`.gltf` + `.bin`）: 障害物のマスの岩山
  - `mountain_B` / `mountain_C`: 双子結晶・迷宮回廊の盤の外の岩山
  - `rock_single_A` / `rock_single_C` / `rock_single_E`: 双子結晶の障害物のマスの岩（上に結晶を生やす）と、盤の外に散らばる石
  - `trees_B_medium`: 双子結晶の盤の外の森
  - `trees_A_cut`（切り株）、`buildings/yellow/building_mine_yellow`（坑口）、`buildings/neutral/building_scaffolding`（足場）、
    `decoration/props/` の `wheelbarrow`・`resource_stone`・`crate_A_big`・`crate_long_A`: 結晶の採掘場の盤の外の景色（2026-11-21 に足した。コミットは同じ `84fa4e9`）
  - `buildings/neutral/building_destroyed`（崩れた家）: 古戦場の盤の外の景色（2026-11-21。コミットは同じ `84fa4e9`）
  - `decoration/props/` の `tent`（天幕）・`weaponrack`（武器の架）・`target`（的）、`buildings/neutral/fence_wood_straight`（木の柵）:
    尾根の小道の盤の外の景色（2026-11-21。コミットは同じ `84fa4e9`）
  - `trees_A_large` / `trees_B_large` / `tree_single_B` / `mountain_B_grass_trees`: リュエルの森の森のマスの大きな木立と、盤の外の森・木の茂る山
    （2026-11-21。コミットは同じ `84fa4e9`）
  - `hexagons_medieval.png`: 上の全部が共通で使うテクスチャ
- 確かめた日: 2026-11-16（`mountain_B` から下を足したとき。コミット `84fa4e9`）

どこにどう置くか（大きさ・向き・色）は `game/stage_look.gd`（マップの見た目）で決めている（元は六角形のマス用）。
