class_name SmokeGrenadeSkill
extends Skill
## スモークグレネード（コマンドー）。離れたマスを中心に煙幕を置く。docs/skills/smoke-grenade.md。
##
## 煙幕そのものの決まり（広さ、離れたところからの攻撃を無効にする、期間）は FieldEffects（docs/field-effects.md）。

# ---- 調整値 ----

const COOLDOWN := 3
## 中心に選べるマスまでの距離（マンハッタン距離。0 は自分のマス）。
const CENTER_RANGE := 3


func id() -> Skill.Id:
	return Skill.Id.SMOKE_GRENADE


func kind() -> UnitKind.Id:
	return UnitKind.Id.COMMANDO


## 説明の文（game/text/names.csv の skill.smoke_grenade.summary）に差し込む値。
func summary_args() -> Dictionary:
	return {"range": CENTER_RANGE, "turns": FieldEffects.SMOKE_TURNS}


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
	return FieldEffects.place_smoke(battle, unit.side, target)
