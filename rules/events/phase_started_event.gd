class_name PhaseStartedEvent
extends BattleEvent
## フェーズが始まった。side はどの陣営の番か。

var turn: int
var side: Unit.Side


func _init(turn_number: int, phase_side: Unit.Side) -> void:
	turn = turn_number
	side = phase_side
