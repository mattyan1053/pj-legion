extends RefCounted
## 勝ち方の文（出撃の準備の「勝ち方」、上の帯の勝ち方の札）。勝ちの条件の列（docs/win-conditions.md）から作る。
## ノードに依存しない（テストから呼べる）。

const Names := preload("res://game/names.gd")


## side から見た、勝ち方と負け方の 2 行。conditions はプレイヤーごとの勝ちの条件の列、hold_turns は守り切るのターン数。
## 対戦モードの勝ち方（将の撃破と本陣の占拠）なら、
## 「敵の将を倒すか、敵の本陣を 3 ターン占拠し続ければ勝ち。」「味方の将が倒されるか、味方の本陣を占拠され続けると負け。」
static func goal(conditions: Array[Array], hold_turns: int, side: Unit.Side) -> String:
	var wins: Array[Array] = []  # [言い切りの形, 「ば」へつなぐ形]
	for condition in _in_order(conditions[side]):
		match condition:
			GameWonEvent.Reason.KING_DEFEATED:
				wins.append(["敵の将を倒す", "敵の将を倒せ"])
			GameWonEvent.Reason.HQ_CAPTURED:
				var text := "敵の本陣を %d ターン占拠し続け" % Battle.CAPTURE_TURNS_TO_WIN
				wins.append([text + "る", text + "れ"])
			GameWonEvent.Reason.TURNS_HELD:
				wins.append(["%d ターン目の終わりまで守り切る" % hold_turns, "%d ターン目の終わりまで守り切れ" % hold_turns])
			GameWonEvent.Reason.ROUTED:
				wins.append(["敵を全滅させる", "敵を全滅させれ"])
	var losses: Array[String] = []
	for condition in _in_order(conditions[1 - side]):
		match condition:
			GameWonEvent.Reason.KING_DEFEATED:
				losses.append("味方の将が倒される")
			GameWonEvent.Reason.HQ_CAPTURED:
				losses.append("味方の本陣を占拠され続ける")
			GameWonEvent.Reason.TURNS_HELD:
				losses.append("%d ターン目の終わりまで守り切られる" % hold_turns)
			GameWonEvent.Reason.ROUTED:
				losses.append("全滅する")
	var lines: Array[String] = []
	if not wins.is_empty():
		var heads: Array[String] = []
		for i in wins.size() - 1:
			heads.append(wins[i][0])
		heads.append(wins[-1][1] + "ば勝ち。")
		var line := "か、".join(heads)
		# 全滅させるが勝ち方にあって、将の撃破が無いなら、将を倒しても終わらないことを言い添える（いつもは将の撃破で終わるので）。
		if conditions[side].has(GameWonEvent.Reason.ROUTED) and not conditions[side].has(GameWonEvent.Reason.KING_DEFEATED):
			line += "敵の将を倒しても、ほかの駒が残っていれば終わらない。"
		lines.append(line)
	if not losses.is_empty():
		losses[-1] += "と負け。"
		lines.append("か、".join(losses))
	return "\n".join(lines)


## 文に並べる順。その戦いならではの勝ち方（守り切る、全滅）を先に、いつもの勝ち方をあとに。
const ORDER: Array[GameWonEvent.Reason] = [
	GameWonEvent.Reason.TURNS_HELD, GameWonEvent.Reason.ROUTED,
	GameWonEvent.Reason.KING_DEFEATED, GameWonEvent.Reason.HQ_CAPTURED,
]


static func _in_order(conditions: Array) -> Array[GameWonEvent.Reason]:
	return ORDER.filter(func(condition: GameWonEvent.Reason) -> bool: return conditions.has(condition))


## 戦いの定義 scenario の、side から見た勝ち方の文（goal）。
static func of_scenario(scenario: Scenario, side: Unit.Side) -> String:
	var conditions: Array[Array] = [scenario.win_conditions_of(Unit.Side.PLAYER1), scenario.win_conditions_of(Unit.Side.PLAYER2)]
	return goal(conditions, scenario.hold_turns, side)


## 上の帯のターンの文（turn は出すターン。再生の途中では、対戦のいまのターンより前のことがある）。「ターン 3」。
## 守り切るの残りは、勝ち方の札（goal_tag）が言葉で出す。
static func turn_text(turn: int) -> String:
	return "ターン %d" % turn


## 上の帯の勝ち方の札: [ひとことの文, 目立たせるか]。side から見る。勝ち方がいつもと同じ戦い（対戦モード）なら ["", false]。
## 詳しい文は goal_note（札にマウスを乗せると出す）。
## - 守り切る: 守る側は「あと 8 ターン守り切れば勝ち」、攻める側は「あと 8 ターンで決着しなければ負け」（いまのターンを含めて数える）。
##   最後のターンは「最後のターン: …」にして目立たせる。
## - 全滅させる: 「勝ち: 敵の全滅（将を倒しても終わらない）」。
static func goal_tag(battle: Battle, turn: int, side: Unit.Side) -> Array:
	var own: Array = battle.win_conditions[side]
	var foe: Array = battle.win_conditions[1 - side]
	var parts: Array[String] = []
	var last := false
	if battle.turns_left() != -1:
		var left := maxi(1, battle.hold_turns - turn + 1)
		last = left == 1
		var holds := own.has(GameWonEvent.Reason.TURNS_HELD)
		if last:
			parts.append("最後のターン: " + ("守り切れば勝ち" if holds else "決着しなければ負け"))
		elif holds:
			parts.append("あと %d ターン守り切れば勝ち" % left)
		else:
			parts.append("あと %d ターンで決着しなければ負け" % left)
	if own.has(GameWonEvent.Reason.ROUTED):
		parts.append("勝ち: 敵の全滅" + ("" if own.has(GameWonEvent.Reason.KING_DEFEATED) else "（将を倒しても終わらない）"))
	if foe.has(GameWonEvent.Reason.ROUTED):
		parts.append("全滅すると負け")
	return ["　".join(parts), last]


## 勝ち方の札にマウスを乗せると出る、詳しい文（side から見た goal）。
static func goal_note(battle: Battle, side: Unit.Side) -> String:
	return goal(battle.win_conditions, battle.hold_turns, side)
