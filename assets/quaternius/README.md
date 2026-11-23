# Quaternius

駒の見た目の組「人物」（`game/looks/quaternius_look.gd`）の素材。魔物の骸骨（`monsters/`）は「ミニ」の組も使う（`game/looks/quaternius_skeleton.gd`）。
骸骨でない魔物（`monsters/` の Bat・Slime）と骸骨旗手は、どの組でも同じ形（`game/looks/monster_body.gd`）。

- 作者: Quaternius（https://quaternius.com）
- ライセンス: CC0 1.0（`LICENSE.txt`。RPG Characters の zip に入っていた `License.txt` をそのまま置いた）。商用・改変・再配布が自由で、クレジット表記は任意
- 取ってきた日・ライセンスを確かめた日: 2026-11-17（配布元のページの「License(s)」が CC0 で、投稿者が作者本人であることを確かめた）
- 改変: なし（FBX のまま。陣営の色・肌・目の塗り替えと、武器の絵の貼り付けは実行時にしている）

## characters/（Ultimate Animated Character Pack - Nov 2019）

- 配布元: https://opengameart.org/content/animated-characters-pack （`ultimate_animated_character_pack_by_quaternius.zip`）
- zip にライセンスの文は入っていない。配布元のページ（作者本人の投稿）が CC0 と書いている。
- 入れたもの: `FBX/` の 9 体。どれも同じ骨と 11 の動き（Idle・Walk・Punch・Shoot_OneHanded・RecieveHit・Defeat・Victory など）を持つ。

| ファイル | 使い道（`quaternius_look.gd` の `KINDS`） |
| --- | --- |
| `Knight_Golden_Male.fbx` | 将 |
| `Soldier_Male.fbx` | シールドトルーパー |
| `Soldier_Female.fbx` | スナイパー |
| `Ninja_Male.fbx` | コマンドー |
| `Doctor_Female_Young.fbx` | 衛生兵 |
| `Knight_Male.fbx` | パラディン |
| `Wizard.fbx` | プリースト |
| `Ninja_Female.fbx` | スペルブレード（2026-11-21 に `Viking_Male` から替えた。同じ zip から。セリスの姿） |
| `Elf.fbx` | ソーサラー |

## weapons/（RPG Characters - Nov 2020）

- 配布元: https://opengameart.org/content/lowpoly-rpg-characters （`rpg_characters_-_nov_2020.zip`）
- 入れたもの: `FBX/Only Weapons/` の 5 つと、`Textures/` のその絵（FBX は絵を中に持たないので、実行時に貼る）。

| ファイル | 使い道（`WEAPONS`） |
| --- | --- |
| `Warrior_Sword.fbx`・`_Texture.png` | 剣（将、前衛、スペルブレード、骸骨重兵） |
| `Rogue_Dagger.fbx`・`_Texture.png` | 短剣（コマンドー、骸骨兵） |
| `Ranger_Bow.fbx`・`_Texture.png` | 弓（スナイパー、骸骨射手） |
| `Wizard_Staff.fbx`・`_Texture.png` | 杖（ソーサラー、骸骨の将） |
| `Cleric_Staff.fbx`・`_Texture.png` | 聖職者の杖（プリースト、骸骨術師） |

## monsters/（Animated Monster Pack - Aug 2018）

- 配布元: https://opengameart.org/content/lowpoly-animated-monsters （`Animated Monster Pack by @Quaternius.zip`。投稿者は作者本人）
- ライセンス: CC0 1.0。配布元のページの「License(s)」が CC0 で、zip の `License.txt` も CC0 1.0 Universal（`monsters/LICENSE.txt` にそのまま置いた。クレジットは任意）
- 取ってきた日・ライセンスを確かめた日: 2026-11-21
- 改変: なし（FBX のまま。骨の色、持ち物、腰の布は実行時に付けている）
- 2026-11-23 に、同じ zip から `Bat.fbx`・`Slime.fbx` を足した（改変なし。面の色の塗り替えと、浮かせる・回すのは実行時）。
- 骨は 17 本（Skeleton）。腕の骨は素材の中で `L.UpperLeg.001`・`L.DownLeg.001` などの名前（脚と同じ名前に `.001` が付いたもの）。
  動きは Skeleton_Idle・Skeleton_Running・Skeleton_Attack・Skeleton_Death・Skeleton_Spawn の 5 つ。

| ファイル | 使い道（`quaternius_skeleton.gd` の `KINDS`・`KING_LOOKS`） |
| --- | --- |
| `Skeleton.fbx` | 骸骨兵・骸骨射手・骸骨重兵・骸骨術師・骸骨鼓手・骸骨の将（「人物」と「ミニ」の組）。骸骨旗手（どの組でも。`game/looks/monster_body.gd`） |
| `Bat.fbx` | 大蝙蝠（どの組でも。`game/looks/monster_body.gd`）。動きは Bat_Flying・Bat_Attack・Bat_Attack2・Bat_Hit・Bat_Death |
| `Slime.fbx` | ほつれ（どの組でも。`game/looks/monster_body.gd`）。動きは Slime_Idle・Slime_Walk・Slime_Attack・Slime_Death |
