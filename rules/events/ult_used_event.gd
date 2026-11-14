class_name UltUsedEvent
extends BattleEvent
## プレイヤーが必殺技を使った。効果のイベント（状態が付いた、など）は、このあとに続く。ゲージは 0 に戻っている。

var side: Unit.Side
var ult: Ult.Id


func _init(user_side: Unit.Side, used: Ult.Id) -> void:
	side = user_side
	ult = used
