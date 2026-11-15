extends "res://tests/base_test.gd"
## 攻撃の当たり方（battle_effects.gd の hit_style）。駒の種類ごとに、docs/battle-view.md の「攻撃の当たり方」の表のとおり。

const BattleEffects := preload("res://prototype/battle_effects.gd")


func test_every_kind_has_a_style() -> void:
	for kind: UnitKind.Id in UnitKind.Id.values():
		assert_true(BattleEffects.STYLE_COLORS.has(BattleEffects.hit_style(kind)), "当たり方の色が無い: %s" % UnitKind.display_name(kind))


func test_styles_follow_the_role() -> void:
	var expected := {
		UnitKind.Id.KING: BattleEffects.Style.SLAM,
		UnitKind.Id.SHIELD_TROOPER: BattleEffects.Style.SLAM,
		UnitKind.Id.PALADIN: BattleEffects.Style.SLAM,
		UnitKind.Id.COMMANDO: BattleEffects.Style.SLASH,
		UnitKind.Id.SPELLBLADE: BattleEffects.Style.SLASH,
		UnitKind.Id.SNIPER: BattleEffects.Style.SHOT,
		UnitKind.Id.SORCERER: BattleEffects.Style.MAGIC,
		UnitKind.Id.PRIEST: BattleEffects.Style.MAGIC,
		UnitKind.Id.ELITE_MINION: BattleEffects.Style.MAGIC,
		UnitKind.Id.MEDIC: BattleEffects.Style.PLAIN,
		UnitKind.Id.MINION: BattleEffects.Style.PLAIN,
	}
	assert_eq(expected.size(), UnitKind.Id.size(), "表に無い種類がある")
	for kind: UnitKind.Id in expected:
		assert_eq(BattleEffects.hit_style(kind), expected[kind], UnitKind.display_name(kind))
