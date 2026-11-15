extends "res://tests/base_test.gd"
## 決着の画面に出す戦績の要点（game/stats_text.gd）。

const StatsText := preload("res://game/stats_text.gd")
const Maps := preload("res://tests/support/maps.gd")

const NAMES: Array[String] = ["青", "赤"]


func test_text_has_the_ending_the_stage_and_both_sides() -> void:
	var battle := Maps.battle(["......"])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER2, Vector2i(5, 0))
	var stats := BattleStats.new(battle)
	stats.units[sniper.id].damage = 42
	stats.units[sniper.id].kills = 2
	stats.units[sniper.id].level = 3
	stats.units[sniper.id].evolution = Evolution.Id.MARKSMAN
	stats.sides[0].damage = 42
	stats.sides[0].kills = 2
	stats.sides[0].relics = [Relics.Id.WISDOM] as Array[Relics.Id]
	stats.ending = BattleStats.Ending.HQ_CAPTURED
	stats.turns = 12
	var text := StatsText.text(stats, "迷宮回廊", NAMES)
	assert_true(text.begins_with("作戦領域: 迷宮回廊　ターン 12　本陣の占拠"), text)
	assert_true(text.contains("青: 与えたダメージ 42　敵軍撃破 2 体"), text)
	assert_true(text.contains("聖遺物 %s" % Relics.display_name(Relics.Id.WISDOM)), text)
	assert_true(text.contains("MVP %s（%s） Lv3　与えたダメージ 42　撃破 2" % [
		UnitKind.display_name(UnitKind.Id.SNIPER), Evolution.display_name(Evolution.Id.MARKSMAN),
	]), text)
	assert_true(text.contains("赤: 与えたダメージ 0"), text)
	assert_false(text.contains("中立撃破"), "倒していなければ、中立撃破は出さない")


func test_side_without_damage_has_no_mvp() -> void:
	var battle := Maps.battle(["......"])
	battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 0))
	var stats := BattleStats.new(battle)
	assert_eq(StatsText.side_lines(stats, Unit.Side.PLAYER1, "青").size(), 1)
