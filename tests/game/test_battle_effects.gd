extends "res://tests/base_test.gd"
## 対戦の演出の割り振り（battle_effects.gd）。攻撃の当たり方は駒の種類ごとに、docs/battle-view.md の「攻撃の当たり方」の表のとおり。
## スキルはどれも、自分の色を持つ（「スキルの形」）。

const Names := preload("res://game/names.gd")
const BattleEffects := preload("res://game/battle_effects.gd")


func test_every_kind_has_a_style() -> void:
	for kind: UnitKind.Id in UnitKind.Id.values():
		assert_true(BattleEffects.STYLE_COLORS.has(BattleEffects.hit_style(kind)), "当たり方の色が無い: %s" % Names.kind(kind))


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
		UnitKind.Id.SKELETON: BattleEffects.Style.SLASH,
		UnitKind.Id.SKELETON_ARCHER: BattleEffects.Style.SHOT,
		UnitKind.Id.SKELETON_BRUTE: BattleEffects.Style.SLAM,
		UnitKind.Id.SKELETON_CALLER: BattleEffects.Style.MAGIC,
		UnitKind.Id.SKELETON_DRUMMER: BattleEffects.Style.MAGIC,
		UnitKind.Id.SKELETON_BANNER: BattleEffects.Style.SLASH,
		UnitKind.Id.BAT: BattleEffects.Style.SLASH,
		UnitKind.Id.FRAY: BattleEffects.Style.SLAM,
		UnitKind.Id.NEEDLE: BattleEffects.Style.SHOT,
		UnitKind.Id.SPIDER: BattleEffects.Style.SLASH,
		UnitKind.Id.EATER: BattleEffects.Style.SLAM,
		UnitKind.Id.CRAB: BattleEffects.Style.SLAM,
		UnitKind.Id.SHROOM: BattleEffects.Style.SLASH,
	}
	assert_eq(expected.size(), UnitKind.Id.size(), "表に無い種類がある")
	for kind: UnitKind.Id in expected:
		assert_eq(BattleEffects.hit_style(kind), expected[kind], Names.kind(kind))


func test_every_skill_has_a_color() -> void:
	for skill: Skill.Id in Skill.Id.values():
		assert_true(BattleEffects.SKILL_COLORS.has(skill), "スキルの色が無い: %s" % Names.skill(Skills.by_id(skill)))
