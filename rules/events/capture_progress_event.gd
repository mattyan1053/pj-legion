class_name CaptureProgressEvent
extends RefCounted
## プレイヤーの、敵の本陣の占拠の数が変わった（または数え直した）。turns は占拠し続けたフェーズの数（0 なら途切れた）。

var player: Unit.Side
var turns: int


func _init(capturing_player: Unit.Side, held_turns: int) -> void:
	player = capturing_player
	turns = held_turns
