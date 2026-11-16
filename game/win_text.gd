extends RefCounted
## 勝ち方の文（出撃の準備の「勝ち方」、上の帯の勝ち方の札）。勝ちの条件の列（docs/win-conditions.md）から作る。
## ノードに依存しない（テストから呼べる）。

const Names := preload("res://game/names.gd")
const Text := preload("res://game/text.gd")


## side から見た、勝ち方と負け方の 2 行。conditions はプレイヤーごとの勝ちの条件の列、hold_turns は守り切るのターン数。
## 対戦モードの勝ち方（将の撃破と本陣の占拠）なら、
## 「敵の将を倒すか、敵の本陣を 3 ターン占拠し続ければ勝ち。」「味方の将が倒されるか、味方の本陣を占拠され続けると負け。」
static func goal(conditions: Array[Array], hold_turns: int, side: Unit.Side) -> String:
	var args := {"turns": hold_turns, "capture": Battle.CAPTURE_TURNS_TO_WIN}
	var lines: Array[String] = []
	var wins := _in_order(conditions[side])
	if not wins.is_empty():
		var line := Text.t("battle.goal.win", {"conditions": _joined(wins, "battle.goal.win.", args)})
		# 全滅させるが勝ち方にあって、将の撃破が無いなら、将を倒しても終わらないことを言い添える（いつもは将の撃破で終わるので）。
		if conditions[side].has(GameWonEvent.Reason.ROUTED) and not conditions[side].has(GameWonEvent.Reason.KING_DEFEATED):
			line += Text.t("battle.goal.rout_note")
		lines.append(line)
	var losses := _in_order(conditions[1 - side])
	if not losses.is_empty():
		lines.append(Text.t("battle.goal.lose", {"conditions": _joined(losses, "battle.goal.lose.", args)}))
	return "\n".join(lines)


## 条件を「Aか、Bか、Cれば」の形につなぐ。鍵は prefix + 条件の名前（並べる形）と、その後ろに .last（最後に置く形）。
static func _joined(conditions: Array[GameWonEvent.Reason], prefix: String, args: Dictionary) -> String:
	var parts: Array[String] = []
	for i in conditions.size():
		var key := prefix + String(GameWonEvent.Reason.find_key(conditions[i])).to_lower()
		parts.append(Text.t(key + (".last" if i == conditions.size() - 1 else ""), args))
	return Text.t("battle.goal.or").join(parts)


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
	return Text.t("battle.goal.turn", {"turn": turn})


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
			parts.append(Text.t("battle.goal.tag.last_hold") if holds else Text.t("battle.goal.tag.last_attack"))
		elif holds:
			parts.append(Text.t("battle.goal.tag.hold", {"left": left}))
		else:
			parts.append(Text.t("battle.goal.tag.attack", {"left": left}))
	if own.has(GameWonEvent.Reason.ROUTED):
		parts.append(Text.t("battle.goal.tag.rout_or_king") if own.has(GameWonEvent.Reason.KING_DEFEATED) else Text.t("battle.goal.tag.rout"))
	if foe.has(GameWonEvent.Reason.ROUTED):
		parts.append(Text.t("battle.goal.tag.routed"))
	return [Text.t("battle.hud.separator").join(parts), last]


## 勝ち方の札にマウスを乗せると出る、詳しい文（side から見た goal）。
static func goal_note(battle: Battle, side: Unit.Side) -> String:
	return goal(battle.win_conditions, battle.hold_turns, side)
