class_name FieldEffectTickedEvent
extends BattleEvent
## 持ち主のフェーズの始めに、煙幕か聖域の残りのターン数が 1 減った（0 になったときは、かわりに FieldEffectRemovedEvent が出る）。

var effect_id: int
var turns_left: int


func _init(ticked_effect_id: int, left: int) -> void:
	effect_id = ticked_effect_id
	turns_left = left
