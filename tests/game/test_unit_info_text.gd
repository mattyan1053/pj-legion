extends "res://tests/base_test.gd"
## 駒の情報の枠に出す文（game/battle_hud.gd の static な関数）: 所属の札、名前、装備の一覧、状態。

const Names := preload("res://game/names.gd")
const BattleHud := preload("res://game/battle_hud.gd")


## 所属の札は、対戦モードでは盤を見ている人から見た「自軍」「敵軍」、ストーリーでは遊ぶ人の側から「味方」「敵」。中立はどちらも「中立」。
func test_side_tag_from_the_viewer() -> void:
	var sniper := Unit.new(1, UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i.ZERO)
	var core := Unit.new(2, UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i.ZERO)
	assert_eq(BattleHud.side_tag(sniper, Unit.Side.PLAYER1), "自軍")
	assert_eq(BattleHud.side_tag(sniper, Unit.Side.PLAYER2), "敵軍")
	assert_eq(BattleHud.side_tag(core, Unit.Side.PLAYER1), "中立")
	Names.story_sides = true
	assert_eq(BattleHud.side_tag(sniper, Unit.Side.PLAYER1), "味方")
	assert_eq(BattleHud.side_tag(Unit.new(3, UnitKind.Id.SNIPER, Unit.Side.PLAYER2, Vector2i.ZERO), Unit.Side.PLAYER1), "敵")
	assert_eq(BattleHud.side_tag(core, Unit.Side.PLAYER1), "中立")
	Names.story_sides = false


## 進化した駒の名前の欄は、進化先の名前と、元の種類。
func test_title_names_the_kind_of_an_evolved_unit() -> void:
	var blade := Unit.new(1, UnitKind.Id.SPELLBLADE, Unit.Side.PLAYER1, Vector2i.ZERO)
	assert_eq(BattleHud.unit_title(blade), Names.kind(UnitKind.Id.SPELLBLADE))
	blade.evolution = Evolution.options_for(UnitKind.Id.SPELLBLADE)[0]
	assert_eq(BattleHud.unit_title(blade), "%s（%s）" % [Names.evolution(blade.evolution), Names.kind(UnitKind.Id.SPELLBLADE)])


func test_equipment_is_counted() -> void:
	var items: Array[Equipment.Id] = [Equipment.Id.SPEED_BOOTS, Equipment.Id.IRON_SHIELD, Equipment.Id.SPEED_BOOTS]
	assert_eq(BattleHud.equipment_text(items), "スピードブーツ ×2・アイアンシールド")
	assert_eq(BattleHud.equipment_text([] as Array[Equipment.Id]), "なし")


func test_every_status_has_a_text() -> void:
	for type: int in Status.Type.values():
		var text := BattleHud.status_text(type as Status.Type, 2)
		assert_true(text.begins_with(Names.status(type as Status.Type)) and text.contains("あと 2 ターン"), text)
