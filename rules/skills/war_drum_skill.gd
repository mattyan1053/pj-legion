class_name WarDrumSkill
extends Skill
## 骨太鼓（骸骨鼓手。魔物）。周りの味方を突撃させる。docs/skills/war-drum.md。
##
## - 自分のマスが対象。自分から RADIUS マス（マンハッタン距離）以内の味方（自分は除く）に、突撃（Status.Type.ASSAULT）が付く
## - 突撃は、総員突撃と同じ状態（移動力と攻撃力が上がる。次の自分の番の始めに外れる）
## - もう行動を終えた味方にも付くが、このフェーズにはもう動けないので、得をしない

# ---- 調整値 ----

const COOLDOWN := 3
## 届く広さ（マンハッタン距離）。
const RADIUS := 3
## 突撃の残りのターン数（付けたときの値）。1 なら、次の自分の番の始めに外れる。
const ASSAULT_TURNS := 1


func id() -> Skill.Id:
	return Skill.Id.WAR_DRUM


func kind() -> UnitKind.Id:
	return UnitKind.Id.SKELETON_DRUMMER


## 説明の文（game/text/names.csv の skill.war_drum.summary）に差し込む値。
func summary_args() -> Dictionary:
	return {"radius": RADIUS, "move": AllOutAssaultUlt.MOVE_BONUS, "power": AllOutAssaultUlt.POWER_BONUS}


func cooldown() -> int:
	return COOLDOWN


func target_cells(_battle: Battle, unit: Unit) -> Array[Vector2i]:
	return [unit.cell]


func affected_cells(battle: Battle, unit: Unit, _target: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in range(-RADIUS, RADIUS + 1):
		for dx in range(-RADIUS, RADIUS + 1):
			var cell := unit.cell + Vector2i(dx, dy)
			if cell != unit.cell and Combat.distance(unit.cell, cell) <= RADIUS and battle.board.in_bounds(cell):
				result.append(cell)
	return result


## 突撃が付く味方（上の行から、左の列から）。
static func drummed(battle: Battle, unit: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	for other in battle.units:
		if other != unit and other.side == unit.side and Combat.distance(unit.cell, other.cell) <= RADIUS:
			result.append(other)
	result.sort_custom(func(a: Unit, b: Unit) -> bool: return Board.in_reading_order(a.cell, b.cell))
	return result


func apply(battle: Battle, unit: Unit, _target: Vector2i) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	for friend in drummed(battle, unit):
		events.append(Statuses.add(friend, Status.Type.ASSAULT, ASSAULT_TURNS))
	return events
