extends "res://tests/base_test.gd"
## 駒の情報の枠に出す文（game/battle_hud.gd の static な関数）: 所属、装備の一覧、状態。

const Names := preload("res://game/names.gd")
const BattleHud := preload("res://game/battle_hud.gd")


func test_affiliation_from_the_viewer() -> void:
	var sniper := Unit.new(1, UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i.ZERO)
	var core := Unit.new(2, UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i.ZERO)
	assert_true(BattleHud.affiliation_text(sniper, Unit.Side.PLAYER1).begins_with("[自軍]"))
	assert_true(BattleHud.affiliation_text(sniper, Unit.Side.PLAYER2).begins_with("[敵軍]"))
	assert_true(BattleHud.affiliation_text(sniper, Unit.Side.PLAYER1).contains("MILITARY"))
	assert_true(BattleHud.affiliation_text(core, Unit.Side.PLAYER1).begins_with("[中立]"))
	var paladin := Unit.new(3, UnitKind.Id.PALADIN, Unit.Side.PLAYER1, Vector2i.ZERO)
	assert_true(BattleHud.affiliation_text(paladin, Unit.Side.PLAYER1, UnitKind.Army.MILITARY).ends_with("MILITARY（FANTASY 出身）"),
			"ほかの軍の駒は、陣営の軍と、駒の種類の軍を並べる")
	assert_true(BattleHud.affiliation_text(sniper, Unit.Side.PLAYER1, UnitKind.Army.MILITARY).ends_with("MILITARY"), "同じ軍なら 1 つだけ")
	var skeleton := Unit.new(4, UnitKind.Id.SKELETON, Unit.Side.PLAYER2, Vector2i.ZERO)
	var monster := BattleHud.affiliation_text(skeleton, Unit.Side.PLAYER1, UnitKind.Army.FANTASY)
	assert_true(monster.begins_with("[敵軍]") and monster.ends_with("魔物"), "魔物は軍の名前のかわりに「魔物」: %s" % monster)
	assert_false(monster.contains("FANTASY"), "魔物に陣営の軍の名前を付けない")


func test_equipment_is_counted() -> void:
	var items: Array[Equipment.Id] = [Equipment.Id.SPEED_BOOTS, Equipment.Id.IRON_SHIELD, Equipment.Id.SPEED_BOOTS]
	assert_eq(BattleHud.equipment_text(items), "スピードブーツ ×2・アイアンシールド")
	assert_eq(BattleHud.equipment_text([] as Array[Equipment.Id]), "なし")


func test_every_status_has_a_text() -> void:
	for type: int in Status.Type.values():
		var text := BattleHud.status_text(type as Status.Type, 2)
		assert_true(text.begins_with(Names.status(type as Status.Type)) and text.contains("あと 2 ターン"), text)
