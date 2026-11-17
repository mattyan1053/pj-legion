# Quaternius

駒の見た目の組「人物」（`game/looks/quaternius_look.gd`）の素材。

- 作者: Quaternius（https://quaternius.com）
- ライセンス: CC0 1.0（`LICENSE.txt`。RPG Characters の zip に入っていた `License.txt` をそのまま置いた）。商用・改変・再配布が自由で、クレジット表記は任意
- 取ってきた日・ライセンスを確かめた日: 2026-11-17（配布元のページの「License(s)」が CC0 で、投稿者が作者本人であることを確かめた）
- 改変: なし（FBX のまま。陣営の色への塗り替えと、武器の絵の貼り付けは実行時にしている）

## characters/（Ultimate Animated Character Pack - Nov 2019）

- 配布元: https://opengameart.org/content/animated-characters-pack （`ultimate_animated_character_pack_by_quaternius.zip`）
- zip にライセンスの文は入っていない。配布元のページ（作者本人の投稿）が CC0 と書いている。
- 入れたもの: `FBX/` の 13 体。どれも同じ骨と 11 の動き（Idle・Walk・Punch・Shoot_OneHanded・RecieveHit・Defeat・Victory など）を持つ。

| ファイル | 使い道（`quaternius_look.gd` の `KINDS`） |
| --- | --- |
| `Knight_Golden_Male.fbx` | 将 |
| `Soldier_Male.fbx` | シールドトルーパー |
| `Soldier_Female.fbx` | スナイパー |
| `Ninja_Male.fbx` | コマンドー |
| `Doctor_Female_Young.fbx` | 衛生兵 |
| `Knight_Male.fbx` | パラディン |
| `Wizard.fbx` | ソーサラー |
| `Viking_Male.fbx` | スペルブレード |
| `Elf.fbx` | プリースト |
| `Zombie_Male.fbx` | 骸骨兵の代わり |
| `Zombie_Female.fbx` | 骸骨射手の代わり |
| `Goblin_Male.fbx` | 骸骨重兵の代わり |
| `Witch.fbx` | 骸骨の将の代わり（`KING_LOOKS` の `skeleton_mage`） |

## weapons/（RPG Characters - Nov 2020）

- 配布元: https://opengameart.org/content/lowpoly-rpg-characters （`rpg_characters_-_nov_2020.zip`）
- 入れたもの: `FBX/Only Weapons/` の 5 つと、`Textures/` のその絵（FBX は絵を中に持たないので、実行時に貼る）。

| ファイル | 使い道（`WEAPONS`） |
| --- | --- |
| `Warrior_Sword.fbx`・`_Texture.png` | 剣（将、前衛、スペルブレード、骸骨重兵の代わり） |
| `Rogue_Dagger.fbx`・`_Texture.png` | 短剣（コマンドー、骸骨兵の代わり） |
| `Ranger_Bow.fbx`・`_Texture.png` | 弓（スナイパー、骸骨射手の代わり） |
| `Wizard_Staff.fbx`・`_Texture.png` | 杖（ソーサラー、骸骨の将の代わり） |
| `Cleric_Staff.fbx`・`_Texture.png` | 聖職者の杖（プリースト） |
