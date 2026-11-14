class_name ShadowStepSkill
extends Skill
## シャドウステップ（スペルブレード）。縦・横・斜めの先のマスへ、間を通らずに移る。docs/skills/shadow-step.md。
##
## - 間のマス（壁、駒、盾、樽、敵の支配領域）は見ない。見るのは、着くマスだけ
## - 着くマスが空いていれば、そこへ移る。敵（相手の陣営の駒と中立の駒）がいれば、その駒と位置を入れ替える
## - **使っても行動を終えない**（Skill.ends_action）。続けて攻撃か待機ができる。もう動けず、移動の取り消しもできない
## - 動いたあとでも使える（歩いてから跳ぶ）。跳んでから歩くことはできない

# ---- 調整値 ----

const COOLDOWN := 3
## 跳べる距離（縦・横・斜めの 8 方向に、このマス数まで）。
const RANGE := 3


func id() -> Skill.Id:
	return Skill.Id.SHADOW_STEP


func kind() -> UnitKind.Id:
	return UnitKind.Id.SPELLBLADE


func display_name() -> String:
	return "シャドウステップ"


func summary() -> String:
	return "縦・横・斜め %d マス以内へ跳ぶ（壁も駒も越える。敵のいるマスなら入れ替わる）。続けて攻撃できる" % RANGE


func cooldown() -> int:
	return COOLDOWN


func ends_action() -> bool:
	return false


func target_cells(battle: Battle, unit: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			for steps in range(1, RANGE + 1):
				var cell := unit.cell + Vector2i(dx, dy) * steps
				if _can_land(battle, unit, cell):
					result.append(cell)
	return result


## 跳んだ先から、続けて攻撃できる。
func threat_origins(battle: Battle, unit: Unit) -> Array[Vector2i]:
	return target_cells(battle, unit)


## cell に着けるか。駒が立てるマス（盤の中で、障害物・樽・盾でない）で、空いているか、敵がいること。
static func _can_land(battle: Battle, unit: Unit, cell: Vector2i) -> bool:
	if not battle.board.is_walkable(cell):
		return false
	var occupant := battle.unit_at(cell)
	return occupant == null or unit.is_enemy_of(occupant)


func apply(battle: Battle, unit: Unit, target: Vector2i) -> Array[BattleEvent]:
	var from := unit.cell
	var other := battle.unit_at(target)
	var events: Array[BattleEvent] = []
	unit.cell = target
	if other == null:
		events.append(UnitTeleportedEvent.new(unit.id, from, target))
	else:
		other.cell = from
		events.append(UnitsSwappedEvent.new(unit.id, from, other.id, target))
	events.append_array(Statuses.displace(unit))
	if other != null:
		events.append_array(Statuses.displace(other))
	return events
