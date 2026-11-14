class_name TacticalBarricadeSkill
extends Skill
## 戦術バリケード（シールドトルーパー）。隣のマスに盾を置く。docs/skills/tactical-barricade.md。
##
## 盾そのものの決まり（入れない、射線を遮る、耐久力）は FieldEffects（docs/field-effects.md）。

# ---- 調整値 ----

const COOLDOWN := 4
## 置けるマスまでの距離（チェビシェフ距離。1 なら周り 8 マス）。
const PLACE_DISTANCE := 1


func id() -> Skill.Id:
	return Skill.Id.TACTICAL_BARRICADE


func kind() -> UnitKind.Id:
	return UnitKind.Id.SHIELD_TROOPER


func display_name() -> String:
	return "戦術バリケード"


func summary() -> String:
	return "周り 8 マスのどこかに盾（耐久 %d。通行と射撃を遮る）を置く" % FieldEffects.BARRICADE_DURABILITY


func cooldown() -> int:
	return COOLDOWN


func target_cells(battle: Battle, unit: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in range(-PLACE_DISTANCE, PLACE_DISTANCE + 1):
		for dx in range(-PLACE_DISTANCE, PLACE_DISTANCE + 1):
			var cell := unit.cell + Vector2i(dx, dy)
			if cell != unit.cell and FieldEffects.can_place_barricade(battle, cell):
				result.append(cell)
	return result


func apply(battle: Battle, unit: Unit, target: Vector2i) -> Array[BattleEvent]:
	return FieldEffects.place_barricade(battle, unit.side, target)
