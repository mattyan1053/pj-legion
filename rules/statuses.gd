class_name Statuses
extends RefCounted
## 駒に付く状態（Status）を付ける・外す・期限を進める処理（docs/unit-statuses.md）。
##
## 状態は駒が「種類 -> 残りのターン数」で持つ（Unit.statuses）。1 体に、同じ種類は 1 つまで。
## 能力値の補正のある状態は、付いている間だけ駒の「一時的な補正」の層（Unit.temporary_bonus）に足される。
## その足し引きは add と remove だけがするので、状態が外れれば（期限、消費、移動）、補正も必ず消える。
##
## - 残りのターン数は、持ち主のフェーズの始めに 1 減り、0 になったら外れる（クールダウン、盤の上の効果と同じ数え方）。
##   N ターンの状態は、付けたターンの N ターン後の、持ち主のフェーズの始めに外れる
## - ここの問い合わせ（has、critical_percent、stat_after_move）は状態を変えない

static func has(unit: Unit, type: Status.Type) -> bool:
	return unit != null and unit.statuses.has(type)


## unit に状態を turns ターン付ける。もう付いていれば、残りのターン数を付け直す（補正は重ねない）。
static func add(unit: Unit, type: Status.Type, turns: int) -> StatusAppliedEvent:
	if not unit.statuses.has(type):
		_shift_bonus(unit, type, 1)
	unit.statuses[type] = turns
	return StatusAppliedEvent.new(unit.id, type, turns)


## unit の状態を外す（付いていることは呼ぶ側が確かめる）。補正も消える。
static func remove(unit: Unit, type: Status.Type, reason: StatusRemovedEvent.Reason) -> StatusRemovedEvent:
	unit.statuses.erase(type)
	_shift_bonus(unit, type, -1)
	return StatusRemovedEvent.new(unit.id, type, reason)


static func _shift_bonus(unit: Unit, type: Status.Type, direction: int) -> void:
	var bonus := Status.bonus(type)
	if bonus.is_empty():
		return
	var before := unit.max_hp()
	for which: Unit.Stat in bonus:
		var amount: int = unit.temporary_bonus.get(which, 0) + direction * bonus[which]
		if amount == 0:
			unit.temporary_bonus.erase(which)
		else:
			unit.temporary_bonus[which] = amount
	unit.follow_max_hp(before)


## unit の付いている状態の種類（種類の番号の順）。
static func types_of(unit: Unit) -> Array[Status.Type]:
	var result: Array[Status.Type] = []
	result.assign(unit.statuses.keys())
	result.sort()
	return result


# ---- 攻撃の解決が読むもの ----


## unit が受けるダメージを 0 にする状態。無ければ -1。
static func blocking(unit: Unit) -> int:
	for type in types_of(unit):
		if Status.blocks_damage(type):
			return type
	return -1


## unit の攻撃の攻撃力に掛ける倍率（%）。クリティカルにする状態が無ければ Status.NORMAL_PERCENT。
static func critical_percent(unit: Unit) -> int:
	var percent := Status.NORMAL_PERCENT
	for type in types_of(unit):
		percent = maxi(percent, Status.critical_percent(type))
	return percent


## unit が攻撃を 1 回した（駒・樽・盾への攻撃。煙幕に阻まれた攻撃も含む）。攻撃で外れる状態を外す。
static func after_attack(unit: Unit) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	for type in types_of(unit):
		if Status.ends_on_attack(type):
			events.append(remove(unit, type, StatusRemovedEvent.Reason.CONSUMED))
	return events


# ---- 移動 ----


## unit がほかのマスへ動いたら、能力値 which の実効値がいくつになるか（動くと外れる状態の補正を除いた値）。
## 状態は変えない。CPU が、動いてから攻撃する手の射程を見積もるのに使う。
static func stat_after_move(unit: Unit, which: Unit.Stat) -> int:
	var lost := 0
	for type in types_of(unit):
		if Status.breaks_on_move(type):
			lost += Status.bonus(type).get(which, 0)
	if lost == 0:
		return unit.stat(which)
	var probe := unit.copy()
	probe.temporary_bonus[which] = probe.temporary_bonus.get(which, 0) - lost
	return probe.stat(which)


## unit がほかのマスへ動いた（MoveAction が呼ぶ）。動くと外れる状態を外す。
## 外す前の状態は unit.statuses_before_move に残し、移動を取り消したら戻す（restore_after_undo）。
static func after_move(unit: Unit) -> Array[BattleEvent]:
	unit.statuses_before_move = unit.statuses.duplicate()
	return displace(unit)


## unit が、移動のほかの形でほかのマスへ移った（スキルで跳んだ、入れ替えられた）。動くと外れる状態を外す。
## 移動の取り消しでは戻らない（外す前の状態を覚えない）。
static func displace(unit: Unit) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	for type in types_of(unit):
		if Status.breaks_on_move(type):
			events.append(remove(unit, type, StatusRemovedEvent.Reason.MOVED))
	return events


## 移動を取り消した（UndoMoveAction が呼ぶ）。動いて外れた状態を、残りのターン数ごと戻す。
static func restore_after_undo(unit: Unit) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	var before: Array[Status.Type] = []
	before.assign(unit.statuses_before_move.keys())
	before.sort()
	for type in before:
		if not unit.statuses.has(type):
			events.append(add(unit, type, unit.statuses_before_move[type]))
	unit.statuses_before_move = {}
	return events


# ---- フェーズの始め ----


## side のフェーズの始めに、side の駒の状態の残りのターン数が 1 減る（EndPhaseAction が、盤の上の効果のあとに呼ぶ）。
## 0 になった状態は外れる（StatusRemovedEvent。駒の番号の順、種類の番号の順）。
## 期限で外れると別の状態に変わるもの（Status.follow_up。高揚 → 反動）は、その駒の期限を全部進めたあとに、続きの状態が付く
## （StatusAppliedEvent。付いたばかりの状態は、このフェーズの始めには減らない）。
static func start_phase(battle: Battle, side: Unit.Side) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	for unit in battle.units:
		if unit.side != side:
			continue
		var next: Array[Array] = []
		for type in types_of(unit):
			unit.statuses[type] -= 1
			if unit.statuses[type] <= 0:
				events.append(remove(unit, type, StatusRemovedEvent.Reason.EXPIRED))
				if not Status.follow_up(type).is_empty():
					next.append(Status.follow_up(type))
		for follow in next:
			events.append(add(unit, follow[0], follow[1]))
	return events
