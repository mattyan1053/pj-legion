extends "res://tests/base_test.gd"
## ゲームの中のものの名前と説明（game/names.gd。文は game/text/names.csv）。列挙の値を足したら、表にも載っていること。

const Names := preload("res://game/names.gd")
const Text := preload("res://game/text.gd")


## 列挙 names の値のすべてについて、鍵 prefix.<名前の小文字><suffix> が表にあるか。skip は載せなくてよい値。
func _assert_keys(prefix: String, names: Dictionary, suffix := "", skip: Array = []) -> void:
	for value: int in names.values():
		if skip.has(value):
			continue
		var key := "%s.%s%s" % [prefix, Names.word(names, value), suffix]
		assert_true(Text.has(key), "画面の文の表に %s が無い" % key)


func test_every_side_has_names() -> void:
	_assert_keys("side", Unit.Side)
	_assert_keys("side", Unit.Side, ".short")


func test_every_army_role_stat_trait_and_field_effect_has_a_name() -> void:
	_assert_keys("army", UnitKind.Army)
	_assert_keys("role", UnitKind.Role, "", [UnitKind.Role.NONE])  # 役割を持たない駒（将、中立）は、役割の名前を出さない
	_assert_keys("stat", Unit.Stat)
	assert_eq(Names.STATS, Unit.Stat.values() as Array[Unit.Stat], "能力の並びが、列挙の順と違う")
	_assert_keys("trait", Evolution.Trait)
	_assert_keys("field_effect", FieldEffect.Type)


func test_every_unit_item_evolution_and_stage_has_a_name() -> void:
	_assert_keys("unit", UnitKind.Id)
	_assert_keys("evolution", Evolution.Id, "", [Evolution.Id.NONE])
	_assert_keys("item", Equipment.Id)
	_assert_keys("stage", BoardGenerator.Stage)
	assert_eq(Names.evolution(Evolution.Id.NONE), "", "進化していなければ空")


func test_every_skill_ult_status_and_relic_has_a_name_and_summary() -> void:
	_assert_keys("skill", Skill.Id)
	_assert_keys("skill", Skill.Id, ".summary")
	_assert_keys("ult", Ult.Id)
	_assert_keys("ult", Ult.Id, ".summary")
	_assert_keys("status", Status.Type)
	_assert_keys("relic", Relics.Id)
	_assert_keys("relic", Relics.Id, ".summary")
	# 説明の文の差し込みは、どれも埋まる（{名前} が残らない）。
	for skill: Skill in Skills.ALL:
		assert_false(Names.skill_summary(skill).contains("{"), "%s の説明に、埋まらない差し込み" % Names.skill(skill))
	for ult: Ult in Ults.ALL:
		assert_false(Names.ult_summary(ult).contains("{"), "%s の説明に、埋まらない差し込み" % Names.ult(ult))
	for id: Relics.Id in Relics.Id.values():
		assert_false(Names.relic_summary(id).contains("{"), Names.relic(id))
	assert_eq(Names.skill_summary(Skills.by_id(Skill.Id.FIREBALL)), "3 マス以内を中心に、十字 5 マスの敵へ 8 ダメージ（壁越し。森で減らない）")
	assert_eq(Names.trait_text(Evolution.Trait.REGENERATION), "自分の番の始めに %d 回復" % Evolution.REGENERATION_HEAL)


func test_a_unit_is_called_by_its_evolution_once_evolved() -> void:
	var battle := Battle.new(Board.new(Vector2i(3, 3)))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 0))
	assert_eq(Names.unit(sniper), "スナイパー")
	sniper.evolution = Evolution.Id.SCOUT
	assert_eq(Names.unit(sniper), "スカウト")
