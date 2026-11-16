extends RefCounted
## 勝ち方の文（出撃の準備の「勝ち方」、上の帯の残りのターン）。勝ちの条件の列（docs/win-conditions.md）から作る。
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
		lines.append("か、".join(heads))
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


## 上の帯のターンの文（turn は出すターン。再生の途中では、対戦のいまのターンより前のことがある）。
## 守り切るがあれば「ターン 3 / 10」（10 は守り切るのターン数）、無ければ「ターン 3」。
static func turn_text(battle: Battle, turn: int) -> String:
	if battle.turns_left() == -1:
		return "ターン %d" % turn
	return "ターン %d / %d" % [turn, battle.hold_turns]


## 上の帯のターンの文にマウスを乗せると出る説明（守り切るの決まり）。守り切るが無ければ空。
static func turn_note(battle: Battle, turn: int) -> String:
	if battle.turns_left() == -1:
		return ""
	var holder := Unit.Side.PLAYER1 if battle.wins_by(Unit.Side.PLAYER1, GameWonEvent.Reason.TURNS_HELD) else Unit.Side.PLAYER2
	return "%d ターン目が終わるまで決着しなければ、%s の勝ち（残り %d ターン）。" % [
		battle.hold_turns, Names.SIDE_NAMES[holder], maxi(0, battle.hold_turns - turn + 1)
	]
