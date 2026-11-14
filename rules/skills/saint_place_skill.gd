class_name SaintPlaceSkill
extends Skill
## セイントプレイス（プリースト）。離れたマスを中心に聖域を置く。docs/skills/saint-place.md。
##
## 聖域そのものの決まり（広さ、回復量、期間）は FieldEffects（docs/field-effects.md）。

# ---- 調整値 ----

const COOLDOWN := 4
## 中心に選べるマスまでの距離（マンハッタン距離。0 は自分のマス）。
const CENTER_RANGE := 2


func id() -> Skill.Id:
	return Skill.Id.SAINT_PLACE


func kind() -> UnitKind.Id:
	return UnitKind.Id.PRIEST


func display_name() -> String:
	return "セイントプレイス"


func summary() -> String:
	return "%d マス以内を中心に聖域（3 x 3。%d ターン。自分の番の始めに中の味方が HP %d 回復）を置く" % [
		CENTER_RANGE, FieldEffects.SANCTUARY_TURNS, FieldEffects.SANCTUARY_HEAL,
	]


func cooldown() -> int:
	return COOLDOWN


func target_cells(battle: Battle, unit: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in range(-CENTER_RANGE, CENTER_RANGE + 1):
		for dx in range(-CENTER_RANGE, CENTER_RANGE + 1):
			var cell := unit.cell + Vector2i(dx, dy)
			if Combat.distance(unit.cell, cell) <= CENTER_RANGE and FieldEffects.can_place_area(battle, cell):
				result.append(cell)
	return result


func affected_cells(battle: Battle, _unit: Unit, target: Vector2i) -> Array[Vector2i]:
	return FieldEffects.area_cells(battle.board, target)


func apply(battle: Battle, unit: Unit, target: Vector2i) -> Array[BattleEvent]:
	return FieldEffects.place_sanctuary(battle, unit.side, target)
