class_name AreaEffectPlacedEvent
extends FieldEffectPlacedEvent
## 煙幕か聖域が置かれた（type で見分ける）。cells は center の周りの 3 x 3 のうち盤の中のもの。
## turns_left は置いたときの残りのターン数。

var turns_left: int


func _init(effect: FieldEffect) -> void:
	_fill(effect)
	turns_left = effect.turns_left
