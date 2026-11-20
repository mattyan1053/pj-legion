class_name BoneRaiseSkill
extends Skill
## 骨起こし（骸骨術師。魔物）。隣の空いたマスに、味方の骸骨兵を 1 体起こす。docs/skills/bone-raise.md。
##
## - 対象は、上下左右の隣の、入れる空いたマス
## - 起きた骸骨兵は、術師の陣営の駒。このフェーズには動けない（行動済みで起きる）。次の自分の番から動く
## - 1 体の術師が、対戦中に使える回数に上限がある（Skill.max_uses）

# ---- 調整値 ----

const COOLDOWN := 3
## 1 体の術師が、対戦中に起こせる数。
const MAX_USES := 2
## 起こす駒の種類。
const RAISED := UnitKind.Id.SKELETON


func id() -> Skill.Id:
	return Skill.Id.BONE_RAISE


func kind() -> UnitKind.Id:
	return UnitKind.Id.SKELETON_CALLER


## 説明の文（game/text/names.csv の skill.bone_raise.summary）に差し込む値。
func summary_args() -> Dictionary:
	return {"uses": MAX_USES}


func cooldown() -> int:
	return COOLDOWN


func max_uses() -> int:
	return MAX_USES


func target_cells(battle: Battle, unit: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for step: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		var cell := unit.cell + step
		if battle.board.in_bounds(cell) and battle.board.is_walkable(cell) and battle.unit_at(cell) == null:
			result.append(cell)
	return result


func apply(battle: Battle, unit: Unit, target: Vector2i) -> Array[BattleEvent]:
	var raised := battle.add_unit(RAISED, unit.side, target)
	if raised == null:
		return []
	raised.acted = true
	return [UnitSpawnedEvent.new(raised)]
