extends CpuPlayer
## 測るための版（--rival に渡す。Issue #47 の「待つのは得か」）: 相手の届く所の手前でそろってから、まとめて踏み込む CPU。
## - そろうまでは、攻撃しない手で相手の届くマスへ入らない（どの役割も、動くだけの手の危険を DANGER_WHILE_GATHERING 倍に見る）。
##   相手を攻撃できる手は、いまの CPU と同じに選ぶ。
## - 自分の番の始めに、戦う駒（前衛・後衛・奇襲）のうち COMMIT_SHARE 以上が「あと 1 歩で相手の届く所」（動けるマスのどれかが、
##   次の相手の番に相手のプレイヤーの駒から攻撃されうる。中立の駒は数えない）か、すでに攻撃を届かせられるなら、その番から先は踏み込む（動くだけの手の危険を、攻撃する手と同じに見る）。
##   ターン COMMIT_BY から先も踏み込む。踏み込んだあとは、いまの CPU と同じ（ただし、ずっと踏み込む重さのまま）。
##
##   godot --headless --path . -s res://tools/cpu_matches.gd -- --games=216 --pairings=mixed --squads=random --rival=res://tools/rivals/massed.gd

const COMMIT_SHARE := 0.75
const COMMIT_BY := 10
const DANGER_WHILE_GATHERING := 4.0

var _committed := false
var _committed_battle: Battle = null
var _checked_turn := -1


func next_action(battle: Battle) -> BattleAction:
	if battle != _committed_battle:
		_committed_battle = battle
		_committed = false
		_checked_turn = -1
	return super.next_action(battle)


func _set_goal(unit: Unit) -> void:
	super._set_goal(unit)
	if not _committed and _battle.turn != _checked_turn:
		_checked_turn = _battle.turn
		_committed = _battle.turn >= COMMIT_BY or _gathered()
	if _committed:
		_idle_danger_weight = minf(_danger_weight, _idle_danger_weight)
	elif unit.kind != UnitKind.Id.KING:
		_idle_danger_weight = maxf(_idle_danger_weight, _danger_weight) * DANGER_WHILE_GATHERING + 1.0


## 戦う駒のうち COMMIT_SHARE 以上が、相手の届く所の際にいるか。
func _gathered() -> bool:
	var fighters := 0
	var front := 0
	for unit in _battle.units:
		if unit.side != _me:
			continue
		var role := UnitKind.role(unit.kind)
		if role == UnitKind.Role.NONE or role == UnitKind.Role.HEALER:
			continue
		fighters += 1
		if _foe_threatens(unit.cell):
			front += 1
			continue
		for cell in _battle.options(unit.id).move_cells:
			if _foe_threatens(cell):
				front += 1
				break
	return fighters > 0 and front >= ceili(COMMIT_SHARE * fighters)


## 次の相手の番に、相手のプレイヤーの駒（中立は除く）が cell を攻撃しうるか。
func _foe_threatens(cell: Vector2i) -> bool:
	for enemy_id: int in _threats.get(cell, {}):
		var enemy := _battle.unit_by_id(enemy_id)
		if enemy != null and enemy.side == _foe:
			return true
	return false
