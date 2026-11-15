extends "res://tests/base_test.gd"
## 駒の情報の枠に出す文（game/battle_hud.gd の static な関数）: 所属、装備の一覧、状態。

const BattleHud := preload("res://game/battle_hud.gd")


func test_affiliation_from_the_viewer() -> void:
	var sniper := Unit.new(1, UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i.ZERO)
	var core := Unit.new(2, UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i.ZERO)
	assert_true(BattleHud.affiliation_text(sniper, Unit.Side.PLAYER1).begins_with("[自軍]"))
	assert_true(BattleHud.affiliation_text(sniper, Unit.Side.PLAYER2).begins_with("[敵軍]"))
	assert_true(BattleHud.affiliation_text(sniper, Unit.Side.PLAYER1).contains("MILITARY"))
	assert_true(BattleHud.affiliation_text(core, Unit.Side.PLAYER1).begins_with("[中立]"))


func test_equipment_is_counted() -> void:
	var items: Array[Equipment.Id] = [Equipment.Id.SPEED_BOOTS, Equipment.Id.IRON_SHIELD, Equipment.Id.SPEED_BOOTS]
	assert_eq(BattleHud.equipment_text(items), "スピードブーツ ×2・アイアンシールド")
	assert_eq(BattleHud.equipment_text([] as Array[Equipment.Id]), "なし")


func test_every_status_has_a_text() -> void:
	for type: int in Status.Type.values():
		var text := BattleHud.status_text(type as Status.Type, 2)
		assert_true(text.begins_with(Status.display_name(type as Status.Type)) and text.contains("あと 2 ターン"), text)
