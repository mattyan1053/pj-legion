class_name TacticUsedEvent
extends BattleEvent
## プレイヤーが作戦を使った。効果のイベント（状態が付いた、回復した、など）は、このあとに続く。

var side: Unit.Side
var tactic: Tactics.Id


func _init(user_side: Unit.Side, used: Tactics.Id) -> void:
	side = user_side
	tactic = used
