extends RefCounted
## 対戦の記録（リプレイ。docs/battle-view.md の「リプレイ」）: 始めの対戦の写しと、受け付けられた行動の列。
## ノードに依存しない。対戦の場面が、対戦を始めたときに作り（of）、行動をルールに渡して受け付けられるたびに足す（add）。
##
## 写しは Battle.clone で取るので、乱数の状態も写る（ルールの乱数は Battle.rng だけ。縫い目の札・拠点の場所は種から決まり、もう盤に入っている）。
## だから、写しに同じ行動を同じ順に当て直すと、同じ出来事が出て、同じ終わりになる（tests/game/test_battle_record.gd）。
## 行動は兵を番号で指すので、写しにもそのまま当てられる（tests/support/cpu_game.gd と同じ形）。
## 残すのはその場かぎり（セーブには書かない）。

var _start: Battle
var actions: Array[BattleAction] = []
## 頭から i 個を当てたあとのターン（i = 0〜行動の数）。当て直して数えるので、初めて聞かれたときに作る。行動を足すと作り直す。
var _turns: Array[int] = []


## battle のいまを写して、記録を始める（まだ行動は無い）。
static func of(battle: Battle) -> RefCounted:
	var record := new()
	record._start = battle.clone()
	return record


func add(action: BattleAction) -> void:
	actions.append(action)
	_turns.clear()


func size() -> int:
	return actions.size()


## 頭から count 個の行動を当て直した、新しい対戦（記録の写しは変えない）。
## on_result(result: ActionResult) を、当てるたびに呼ぶ（戦績やログに食わせる）。断られたら、そこで止める。
func battle_at(count: int, on_result := Callable()) -> Battle:
	var battle := _start.clone()
	for i in mini(count, actions.size()):
		var result := battle.apply(actions[i])
		if not result.accepted:
			push_error("battle_record: 記録した行動が、当て直すと断られた（%d 個目）" % i)
			break
		if on_result.is_valid():
			on_result.call(result)
	return battle


## 頭から count 個を当てたあとのターン。
func turn_at(count: int) -> int:
	_count_turns()
	return _turns[clampi(count, 0, _turns.size() - 1)]


## ターン turn の頭（そのターンの最初の行動の前。行動の数で言う）。記録に無いターンなら -1。
## 頭はそのターンに入った行動のすぐあと（中立の番は、前の番を終える行動の中で済んでいる）。始めのターンは 0。
func head_of(turn: int) -> int:
	_count_turns()
	for i in _turns.size():
		if _turns[i] == turn:
			return i
	return -1


## いちばん後のターン（決着したターン）。
func last_turn() -> int:
	_count_turns()
	return _turns[-1]


func _count_turns() -> void:
	if not _turns.is_empty():
		return
	var battle := _start.clone()
	_turns.append(battle.turn)
	for action in actions:
		battle.apply(action)
		_turns.append(battle.turn)
