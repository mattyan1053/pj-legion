class_name FieldEffectRemovedEvent
extends BattleEvent
## 盤の上の効果が消えた。cells は効果のあったマス。

enum Reason {
	EXPIRED,  ## 残りのターン数が 0 になった（煙幕・聖域）
	DESTROYED,  ## 耐久力が 0 になった（盾）
	UNTIED,  ## 持ち主のフェーズの始めに、ほかの陣営の駒が乗っていて、ほどけた（結び目）
	REFORMED,  ## 残りのターン数が 0 になり、そこに駒が立ち直った（結び目。続けて UnitSpawnedEvent）
}

var effect_id: int
var type: FieldEffect.Type
var cells: Array[Vector2i]
var reason: Reason


func _init(effect: FieldEffect, why: Reason) -> void:
	effect_id = effect.id
	type = effect.type
	cells = effect.cells.duplicate()
	reason = why
