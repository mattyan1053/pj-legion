class_name FireballSkill
extends Skill
## ファイアボール（ソーサラー）。離れたマスを中心に、十字 5 マスの敵へ固定のダメージ。docs/skills/fireball.md。
##
## - 地形（壁）にも盾にも遮られない。森の軽減は無い。煙幕にも防がれない（駒の攻撃ではない）
## - 当たるのは敵（相手の陣営の駒と中立の駒）だけ。味方、樽、盾には当たらない
## - ダメージと経験値の入り方は、ダメージのあるスキルの共通の入口（Skills.deal_damage）

# ---- 調整値 ----

const COOLDOWN := 4
## 中心に選べるマスまでの距離（マンハッタン距離。0 は自分のマス）。
const CENTER_RANGE := 3
## 範囲の駒 1 体ずつへのダメージ（固定。攻撃力にも森にもよらない）。
const DAMAGE := 8
## 範囲の広がり（中心からの、上下左右のマス数。1 なら十字 5 マス）。
const ARM := 1


func id() -> Skill.Id:
	return Skill.Id.FIREBALL


func kind() -> UnitKind.Id:
	return UnitKind.Id.SORCERER


func display_name() -> String:
	return "ファイアボール"


func summary() -> String:
	return "%d マス以内を中心に、十字 5 マスの敵へ %d ダメージ（壁越し。森で減らない）" % [CENTER_RANGE, DAMAGE]


func cooldown() -> int:
	return COOLDOWN


func target_cells(battle: Battle, unit: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in range(-CENTER_RANGE, CENTER_RANGE + 1):
		for dx in range(-CENTER_RANGE, CENTER_RANGE + 1):
			var cell := unit.cell + Vector2i(dx, dy)
			if Combat.distance(unit.cell, cell) <= CENTER_RANGE and battle.board.in_bounds(cell):
				result.append(cell)
	return result


## 中心と、その上下左右 ARM マスのうち、盤の中のもの。上の行から、左の列から。
func affected_cells(battle: Battle, _unit: Unit, target: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in range(-ARM, ARM + 1):
		for dx in range(-ARM, ARM + 1):
			var cell := target + Vector2i(dx, dy)
			if (dx == 0 or dy == 0) and battle.board.in_bounds(cell):
				result.append(cell)
	return result


## 選べる中心のどれかの範囲に入るマスすべてに DAMAGE（味方のいるマスも含む。だれが立つかで当たるかが変わるため）。
func threat_damage(battle: Battle, unit: Unit) -> Dictionary[Vector2i, int]:
	var result: Dictionary[Vector2i, int] = {}
	for center in target_cells(battle, unit):
		for cell in affected_cells(battle, unit, center):
			result[cell] = DAMAGE
	return result


func apply(battle: Battle, unit: Unit, target: Vector2i) -> Array[BattleEvent]:
	var hits: Array[Array] = []
	for cell in affected_cells(battle, unit, target):
		var victim := battle.unit_at(cell)
		if victim != null and unit.is_enemy_of(victim):
			hits.append([victim, DAMAGE])
	return Skills.deal_damage(battle, unit, hits)
