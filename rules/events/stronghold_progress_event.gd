class_name StrongholdProgressEvent
extends BattleEvent
## プレイヤーの、拠点の確保の数が変わった（試しの決まりの拠点。docs/win-conditions.md の「拠点を確保し続ける」）。
## holds は確保の数（0 なら、相手に上書きされた）。

var player: Unit.Side
var holds: int


func _init(holding_player: Unit.Side, held: int) -> void:
	player = holding_player
	holds = held
