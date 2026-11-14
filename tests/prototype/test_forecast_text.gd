extends "res://tests/base_test.gd"
## 戦闘予測の文（prototype/forecast_text.gd）: どの行動の予測も文にでき、起きることが文に出ること。

const Maps := preload("res://tests/support/maps.gd")
const ForecastText := preload("res://prototype/forecast_text.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2


func _text(battle: Battle, action: BattleAction, actor: Unit) -> String:
	return ForecastText.describe(battle, Forecast.of(battle, action), actor)


func test_attack_text_shows_damage_and_defeat() -> void:
	var battle := Maps.battle([
		".....",
		"..B..",
		".....",
	])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var king := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(1, 0))
	king.hp = 1
	var text := _text(battle, AttackAction.new(commando.id, king.id), commando)
	assert_true(text.contains("倒れる"), text)
	assert_true(text.contains("経験"), text)
	assert_true(text.contains("の勝ち"), text)
	king.hp = king.max_hp()
	commando.cell = Vector2i(1, 1)
	var blast := _text(battle, AttackBarrelAction.new(commando.id, Vector2i(2, 1)), commando)
	assert_true(blast.contains("爆発"), blast)
	assert_true(blast.contains("自分"), "自分も巻き込まれる: " + blast)


func test_skill_heal_barricade_and_ult_texts() -> void:
	var battle := Maps.battle([
		"......",
		"......",
		"......",
	])
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(0, 1))
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(1, 1))
	trooper.hp -= 5
	assert_true(_text(battle, HealAction.new(medic.id, trooper.id), medic).contains("+5"))
	assert_true(_text(battle, UseSkillAction.new(trooper.id, Vector2i(0, 0)), trooper).contains("を置く"))
	FieldEffects.place_barricade(battle, P2, Vector2i(0, 2))
	assert_true(_text(battle, AttackBarricadeAction.new(trooper.id, Vector2i(0, 2)), trooper).contains("盾: 耐久"))
	battle.ult_gauge[P1] = Ults.GAUGE_MAX
	assert_true(_text(battle, UseUltAction.new(), trooper).contains(Status.display_name(Status.Type.ASSAULT)))
	assert_eq(_text(battle, WaitAction.new(medic.id), medic), "何も起きない")
