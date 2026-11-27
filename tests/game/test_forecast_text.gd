extends "res://tests/base_test.gd"
## 戦闘予測の文（game/forecast_text.gd）: どの行動の予測も文にでき、起きることが文に出ること。

const Names := preload("res://game/names.gd")
const Maps := preload("res://tests/support/maps.gd")
const ForecastText := preload("res://game/forecast_text.gd")

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
	assert_true(_text(battle, UseUltAction.new(), trooper).contains(Names.status(Status.Type.ASSAULT)))
	assert_eq(_text(battle, WaitAction.new(medic.id), medic), "何も起きない")


func test_summary_marks_defeats_self_damage_and_blocks() -> void:
	var battle := Maps.battle([
		".....",
		"..B..",
		".....",
	])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 1))
	var king := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(3, 1))
	king.hp = 1
	var summary := ForecastText.summarize(battle, Forecast.of(battle, AttackBarrelAction.new(commando.id, Vector2i(2, 1))), commando)
	assert_true(summary.hurts_actor, "自分も爆発に巻き込まれる")
	assert_eq(summary.defeats, 1)
	assert_true(summary.decides, "将が倒れて決着する")
	var own: ForecastText.Row = null
	for row in summary.rows:
		if row.is_actor:
			own = row
	assert_true(own != null and own.notes.has("爆発") and own.damage == MapObject.BLAST_DAMAGE)
	# バリアに防がれると 0 ダメージで、防いだ理由が出る。倒せる数には入らない。
	king.hp = king.max_hp()
	Statuses.add(king, Status.Type.BARRIER, 1)
	commando.cell = Vector2i(2, 2)
	king.cell = Vector2i(3, 2)
	var blocked := ForecastText.summarize(battle, Forecast.of(battle, AttackAction.new(commando.id, king.id)), commando)
	assert_true(blocked.rows[0].blocked and blocked.rows[0].damage == 0, "バリアで 0 ダメージ")
	assert_eq(ForecastText.hp_text(blocked.rows[0]), "0 ダメージ")
	assert_eq(blocked.defeats, 0)


func test_summary_heal_row_and_level_up() -> void:
	var battle := Maps.battle([
		"....",
		"....",
	])
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(0, 0))
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(1, 0))
	trooper.hp = 10
	medic.experience = Growth.EXPERIENCE_PER_LEVEL - 1
	var summary := ForecastText.summarize(battle, Forecast.of(battle, HealAction.new(medic.id, trooper.id)), medic)
	assert_eq(ForecastText.hp_text(summary.rows[0]), "+%d → HP %d / %d" % [medic.power(), 10 + medic.power(), trooper.max_hp()])
	var growth := "\n".join(summary.rows[1].effects)
	assert_true(growth.contains("レベルアップ（Lv2）"), growth)


## 受けるダメージを減らす軍略（隊列・守護）は、注に「-」で出る。
func test_shield_traits_show_as_a_cut() -> void:
	var battle := Maps.battle([
		".....",
		".....",
		".....",
	])
	battle.traits[P2] = Traits.Id.GUARD
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 1))
	var target := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(1, 1))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(1, 2))
	var text := _text(battle, AttackAction.new(commando.id, target.id), commando)
	var cut := "%s -%d" % [Names.troop_trait(Traits.Id.GUARD), Traits.GUARD_SHIELD]
	assert_true(text.contains(cut), text)
