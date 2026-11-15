# 150 Combat Sound Effects（Untamed Pixels がまとめたもの）の効果音

- まとめた人: Untamed Pixels（OpenGameArt のユーザー。https://opengameart.org/users/untamedpixels ）
- 配布元: 150 Combat Sound Effects — https://opengameart.org/content/150-combat-sound-effects （`150gameeffectsounds.zip`）
- ライセンス: CC0 1.0（`LICENSE.txt`）。配布元のページの「License(s)」が CC0。zip の `LICENSES.txt` が、入っている 150 の音すべてを CC0 とし、元の作者ごとに出どころを書いている（使った分を `LICENSE.txt` に写した）
- 取ってきた日・ライセンスを確かめた日: 2026-11-15
- 改変: 配布元の WAV（48 kHz ステレオ）を、モノラルの Ogg Vorbis（品質 3）にし、長いものは後ろを切って短いフェードで消した（CC0 なので改変してよい）。ファイル名は小文字にした

| ファイル | 使う音（`game/sound_catalog.gd`） | 元のファイル（zip の中） | 元の作者 | 長さ |
| --- | --- | --- | --- | --- |
| `impact_punch_heavy_002.ogg` | `hit_slam`（叩く攻撃が当たった） | `01_combat_melee/impact_punch_heavy_002_48kHz_16bit_0.46s_565485a1_s02.wav` | Kenney（Impact Sounds） | 0.46 秒（そのまま） |
| `fire_spell_impact_4.ogg` | `skill_fire`（ファイアボール）、`explosion`（樽の爆発） | `04_magic_spells/Fire Spell Impact 4_s06.wav` | lentikula（Basic Spell Impacts） | 1.88 → 1.3 秒 |
| `earth_spell_impact_4.ogg` | `skill_guard`（バリケード、ディバインシールド） | `04_magic_spells/Earth Spell Impact 4_s07.wav` | lentikula（Druid Spell Impacts） | 1.88 → 1.2 秒 |
| `ice_spell_impact_5.ogg` | `skill_focus`（照準、アドレナリン注射） | `04_magic_spells/Ice Spell Impact 5_s06.wav` | lentikula（Basic Spell Impacts） | 1.80 → 1.0 秒 |
| `wind_spell_impact_5.ogg` | `skill_wind`（スモークグレネード、シャドウステップ） | `04_magic_spells/Wind Spell Impact 5_s07.wav` | lentikula（Druid Spell Impacts） | 3.30 → 1.2 秒 |
| `healing_spell_impact_10.ogg` | `heal`（回復） | `04_magic_spells/Healing Spell Impact 10_s08.wav` | lentikula（Healing Spell Impacts） | 2.00 → 1.0 秒 |
| `healing_spell_impact_11.ogg` | `skill_holy`（聖域） | `04_magic_spells/Healing Spell Impact 11_s08.wav` | lentikula（Healing Spell Impacts） | 3.34 → 1.6 秒 |
| `healing_spell_impact_3.ogg` | `evolved`（進化した） | `04_magic_spells/Healing Spell Impact 3_s08.wav` | lentikula（Healing Spell Impacts） | 2.50 → 1.8 秒 |
| `lightning_spell_impact_3.ogg` | `ult`（必殺技） | `04_magic_spells/Lightning Spell Impact 3_s06.wav` | lentikula（Basic Spell Impacts） | 3.75 → 1.8 秒 |

パックの全部は入れていない（使う音だけ）。パックには電子音・8bit 風の音（`Retro`、`Laser`、`Zap` など）も入っているが、それは使わない（`docs/sound.md` の「方向」）。
