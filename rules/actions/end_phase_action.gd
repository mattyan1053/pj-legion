class_name EndPhaseAction
extends BattleAction
## いまのプレイヤーのフェーズを終え、次のフェーズへ進める（「ターン終了」）。
##
## 全部の駒が行動を終えても、フェーズは自動では終わらない。未行動の駒が残っていても終えてよい。
## 行動の途中の駒がいれば、待機したことにして終える。
## プレイヤー2 のあとの中立のフェーズ（Neutral.play_phase）は、続けてこの中で進め、次のターンのプレイヤー1 のフェーズまで進む。
## 中立のフェーズで決着したら、そこで止まる。中立のフェーズのあと、ターンの終わりに決まること（守り切る。Battle.end_turn）で
## 決着しても、そこで止まる（次のターンへは進まない）。
## プレイヤーのフェーズの始めに、回復の泉に乗っているそのプレイヤーの駒が回復し、続けて再生の特性の駒が回復する。
## そのあと、そのプレイヤーの盤の上の効果が働き、期間が進む（聖域の回復、煙幕・聖域の残りのターン数。FieldEffects.start_phase）。
## 続けて、そのプレイヤーの駒の状態の残りのターン数が 1 減り、0 になった状態は外れる（Statuses.start_phase）。
## 続けて、そのプレイヤーの駒のスキルのクールダウンが 1 減る（Skills.start_phase）。
## 最後に、そのプレイヤーの必殺技のゲージがたまる（Ults.charge_phase）。
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
	CenterPoint.end_phase(battle, battle.phase)
	if battle.is_over():
		return events

	if battle.phase == Unit.Side.PLAYER1:
		events.append_array(_start_phase(battle, Unit.Side.PLAYER2))
		if battle.is_over():
			return events
	else:
		events.append_array(_start_phase(battle, Unit.Side.NEUTRAL))
		events.append_array(Neutral.play_phase(battle))
		if battle.is_over():
			return events  # 中立の駒の攻撃で将が倒れた
		events.append_array(battle.end_turn())
		if battle.is_over():
			return events  # 守り切った
		battle.turn += 1
		events.append_array(_start_phase(battle, Unit.Side.PLAYER1))
	return events


static func _start_phase(battle: Battle, side: Unit.Side) -> Array[BattleEvent]:
	battle.phase = side
	for unit in battle.units:
		if unit.side == side:
			unit.reset_action()
	var events: Array[BattleEvent] = [PhaseStartedEvent.new(battle.turn, side)]
	for unit in MapObject.spring_targets(battle, side):
		var amount := MapObject.spring_heal(unit)
		unit.hp += amount
		events.append(SpringHealedEvent.new(unit.cell, unit.id, amount, unit.hp))
	for unit in Evolution.regeneration_targets(battle, side):
		var amount := Evolution.regeneration_heal(unit)
		unit.hp += amount
		events.append(RegenerationHealedEvent.new(unit.id, amount, unit.hp))
	events.append_array(FieldEffects.start_phase(battle, side))
	events.append_array(Statuses.start_phase(battle, side))
	events.append_array(Skills.start_phase(battle, side))
	Ults.charge_phase(battle, side)
	CenterPoint.start_phase(battle, side)
	return events
