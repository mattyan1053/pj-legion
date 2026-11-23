extends RefCounted
## 勝ち方の文（出撃準備の「勝ち方」、上の帯の勝ち方の札）。勝ちの条件の列（docs/win-conditions.md）から作る。
## ノードに依存しない（テストから呼べる）。

const Names := preload("res://game/names.gd")
const Text := preload("res://game/text.gd")


## side から見た、勝ち方と負け方の 2 行。conditions はプレイヤーごとの勝ちの条件の列、hold_turns は守り切るのターン数。
## 対戦モードの勝ち方（将の撃破と本陣の占拠）なら、
## 「敵の将を倒すか、敵の本陣を 3 ターン占拠し続ければ勝ち。」「味方の将が倒されるか、味方の本陣を占拠され続けると負け。」
## foe_has_king が偽（相手が将のいない群れ。docs/scenario.md）なら、「将を倒しても終わらない」は言い添えない（倒す将がいない）。
static func goal(conditions: Array[Array], hold_turns: int, side: Unit.Side, foe_has_king := true) -> String:
	var args := {"turns": hold_turns, "capture": Battle.CAPTURE_TURNS_TO_WIN, "holds": Stronghold.HOLDS_TO_WIN}
	var lines: Array[String] = []
	var wins := _in_order(conditions[side])
	if not wins.is_empty():
		var line := Text.t("battle.goal.win", {"conditions": _joined(wins, "battle.goal.win.", args)})
		# 全滅させるが勝ち方にあって、将の撃破が無いなら、将を倒しても終わらないことを言い添える（いつもは将の撃破で終わるので）。
		if not foe_has_king:
			pass
		elif conditions[side].has(GameWonEvent.Reason.ROUTED) and not conditions[side].has(GameWonEvent.Reason.KING_DEFEATED):
			line += Text.t("battle.goal.rout_note")
		elif conditions[side].has(GameWonEvent.Reason.BOSS_SLAIN) and not conditions[side].has(GameWonEvent.Reason.KING_DEFEATED):
			line += Text.t("battle.goal.boss_note")
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
	GameWonEvent.Reason.TURNS_HELD, GameWonEvent.Reason.ROUTED, GameWonEvent.Reason.BOSS_SLAIN,
	GameWonEvent.Reason.KING_DEFEATED, GameWonEvent.Reason.HQ_CAPTURED, GameWonEvent.Reason.STRONGHOLD_HELD,
]


static func _in_order(conditions: Array) -> Array[GameWonEvent.Reason]:
	return ORDER.filter(func(condition: GameWonEvent.Reason) -> bool: return conditions.has(condition))


## 戦いの定義 scenario の、side から見た勝ち方の文（goal）。
static func of_scenario(scenario: Scenario, side: Unit.Side) -> String:
	var conditions: Array[Array] = [scenario.win_conditions_of(Unit.Side.PLAYER1), scenario.win_conditions_of(Unit.Side.PLAYER2)]
	return goal(conditions, scenario.hold_turns, side, scenario.has_king((1 - side) as Unit.Side))


## 上の帯のターンの文（turn は出すターン。再生の途中では、対戦のいまのターンより前のことがある）。「ターン 3」。
## 守り切るの残りは、勝ち方の札（goal_tag）が言葉で出す。
static func turn_text(turn: int) -> String:
	return Text.t("battle.goal.turn", {"turn": turn})


## 上の帯の勝ち方の札: [ひとことの文, 目立たせるか]。side から見る。勝ち方がいつもと同じ戦い（対戦モード）なら ["", false]。
## 詳しい文は goal_note（札にマウスを乗せると出す）。
## - 守り切る: 守る側は「あと 8 ターン守り切れば勝ち」、攻める側は「あと 8 ターンで決着しなければ負け」（いまのターンを含めて数える）。
##   最後のターンは「最後のターン: …」にして目立たせる。
## - 全滅させる: 「勝ち: 敵の全滅（将を倒しても終わらない）」。敵の将が盤にいなければ（将のいない群れ）、「勝ち: 敵の全滅」。
## - 中ボスの撃破: 「勝ち: 中ボスの撃破（将を倒しても終わらない）」。
## - 拠点の確保（選べる決まり）: 「拠点の確保 6 回で勝ち　青 ●●○○○○　赤 ○○○○○○」（両方の陣営の確保の数）。
##   どちらかがあと 1 回で勝つなら、頭を「あと 1 回の確保で青の勝ち」にして目立たせる（自分の側を先に見る）。
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
	# 敵の将がいなければ（将のいない群れ。倒れたあとも）、「将を倒しても終わらない」は言わない。
	var foe_king := _has_king(battle, (1 - side) as Unit.Side)
	if own.has(GameWonEvent.Reason.ROUTED):
		var plain := own.has(GameWonEvent.Reason.KING_DEFEATED) or not foe_king
		parts.append(Text.t("battle.goal.tag.rout_or_king") if plain else Text.t("battle.goal.tag.rout"))
	if own.has(GameWonEvent.Reason.BOSS_SLAIN):
		if not foe_king:
			parts.append(Text.t("battle.goal.tag.boss_only"))
		else:
			parts.append(Text.t("battle.goal.tag.boss_or_king") if own.has(GameWonEvent.Reason.KING_DEFEATED) else Text.t("battle.goal.tag.boss"))
	if foe.has(GameWonEvent.Reason.ROUTED):
		parts.append(Text.t("battle.goal.tag.routed"))
	# 拠点の確保（選べる決まり）は、勝ち方の札でなく、拠点の札（stronghold_goal など。上の帯の下）に出す。
	return [Text.t("battle.hud.separator").join(parts), last]


## 上の帯の勝ち方の札に並べる印（GameWonEvent.Reason の並び。goal_mark.gd）: 札の文が言う勝ち方（守り切る・全滅・中ボスの撃破）。
## 「対戦ルール」と出撃準備の勝ち方の欄と同じ印で、同じものだと分かるようにする。札を出さない対戦（goal_tag の文が空）では空。
static func goal_tag_marks(battle: Battle, side: Unit.Side) -> Array[int]:
	var marks: Array[int] = []
	if battle.turns_left() != -1:
		marks.append(GameWonEvent.Reason.TURNS_HELD)
	for reason: GameWonEvent.Reason in [GameWonEvent.Reason.ROUTED, GameWonEvent.Reason.BOSS_SLAIN]:
		if battle.win_conditions[side].has(reason):
			marks.append(reason)
	return marks


## 拠点の札の勝つ数（拠点の無い対戦か、どちらの勝ちの条件にも拠点の確保が無ければ 0。札を出さない）。
static func stronghold_goal(battle: Battle) -> int:
	if battle.board.stronghold_cell == Board.NO_CELL:
		return 0
	for player: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		if battle.wins_by(player, GameWonEvent.Reason.STRONGHOLD_HELD):
			return Stronghold.HOLDS_TO_WIN
	return 0


## あと 1 回の確保で勝つ陣営（いなければ -1）。
static func stronghold_near(battle: Battle) -> int:
	for player: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		if Stronghold.holds_left(battle, player) == 1:
			return player
	return -1


## 拠点の札にマウスを乗せると出る文（決まりと、あと 1 回で勝つ陣営）。
static func stronghold_note(battle: Battle) -> String:
	var lines: Array[String] = [Text.t("battle.stronghold.rule", stronghold_args())]
	var near := stronghold_near(battle)
	if near >= 0:
		lines.push_front(Text.t("battle.goal.tag.stronghold_near", {"side": Names.side_word(near)}))
	return "\n".join(lines)


## 拠点の決まりの文に差し込む値。
static func stronghold_args() -> Dictionary:
	return {"needed": Stronghold.HOLDS_TO_WIN}


## 勝ち方の札にマウスを乗せると出る、詳しい文（side から見た goal）。
static func goal_note(battle: Battle, side: Unit.Side) -> String:
	return goal(battle.win_conditions, battle.hold_turns, side, _has_king(battle, (1 - side) as Unit.Side))


## side の将が盤にいるか。
static func _has_king(battle: Battle, side: Unit.Side) -> bool:
	for unit in battle.units:
		if unit.side == side and unit.kind == UnitKind.Id.KING:
			return true
	return false
