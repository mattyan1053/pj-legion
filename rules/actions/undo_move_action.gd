class_name UndoMoveAction
extends BattleAction
## 動いたあと、攻撃も待機もしていない駒を、動く前のマスへ戻す。駒は行動前の状態に戻る。
## 行動を終えないスキル（シャドウステップ）を使ったあとは、取り消せない（Unit.move_locked）。
## 動いたことで外れた状態（照準）は、残りのターン数ごと戻る（StatusAppliedEvent）。
## 動いたことで本陣の占拠の数が 0 に戻っていたら、それも動く前の数へ戻す。

var unit_id: int


func _init(moved_unit_id: int) -> void:
	unit_id = moved_unit_id


func is_valid(battle: Battle) -> bool:
	var unit := battle.unit_by_id(unit_id)
	return battle.can_act(unit) and unit.has_moved and not unit.move_locked


func execute(battle: Battle) -> Array[BattleEvent]:
	var unit := battle.unit_by_id(unit_id)
	var from := unit.cell
	unit.cell = unit.move_origin
	unit.has_moved = false
	unit.on_the_move = unit.on_the_move_before_move
	unit.cruised = false
	battle.acting_unit_id = 0
	var events: Array[BattleEvent] = [MoveUndoneEvent.new(unit.id, from, unit.cell)]
	events.append_array(Statuses.restore_after_undo(unit))
	for player: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		var before := battle.capture_turns_before_move[player]
		if battle.capture_turns[player] != before:
			battle.capture_turns[player] = before
			events.append(CaptureProgressEvent.new(player, before))
	return events
