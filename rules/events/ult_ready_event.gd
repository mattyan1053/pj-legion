class_name UltReadyEvent
extends BattleEvent
## プレイヤーの必殺技のゲージがいっぱいになった（次の自分のフェーズから使える）。
## その行動で起きたことの最後に出る（Battle.apply）。

var side: Unit.Side
var ult: Ult.Id


func _init(ready_side: Unit.Side, ready_ult: Ult.Id) -> void:
	side = ready_side
	ult = ready_ult
