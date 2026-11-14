class_name EndPhaseAction
extends BattleAction
## いまのプレイヤーのフェーズを終え、次のフェーズへ進める（「ターン終了」）。
##
## 全部の駒が行動を終えても、フェーズは自動では終わらない。未行動の駒が残っていても終えてよい。
## 行動の途中の駒がいれば、待機したことにして終える。
## プレイヤー2 のあとの中立のフェーズは、続けてこの中で進め、次のターンのプレイヤー1 のフェーズまで進む。
## フェーズを終える前に、敵の本陣の占拠を数える。それで勝ちが決まれば、次のフェーズへは進まない。

func is_valid(battle: Battle) -> bool:
	return battle.phase != Unit.Side.NEUTRAL


func execute(battle: Battle) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	var acting := battle.unit_by_id(battle.acting_unit_id)
	if acting != null:
		events.append(battle.finish_action(acting))
	events.append_array(battle.count_capture(battle.phase))
	if battle.is_over():
		return events

	if battle.phase == Unit.Side.PLAYER1:
		events.append_array(_start_phase(battle, Unit.Side.PLAYER2))
	else:
		events.append_array(_start_phase(battle, Unit.Side.NEUTRAL))
		# 中立の駒の動きは、中立の仕様で入れる。いまは何もせずに通り過ぎる。
		battle.turn += 1
		events.append_array(_start_phase(battle, Unit.Side.PLAYER1))
	return events


static func _start_phase(battle: Battle, side: Unit.Side) -> Array[BattleEvent]:
	battle.phase = side
	for unit in battle.units:
		if unit.side == side:
			unit.reset_action()
	return [PhaseStartedEvent.new(battle.turn, side)]
