class_name CutLeftEvent
extends BattleEvent
## 台本の出来事（カットシーン）: 兵が、倒れずに去る。道順 path（いまのマスから。1 マスだけなら、その場で）を歩いてから、薄れて消える。

var unit_id: int
var path: Array[Vector2i] = []


func _init(left_unit_id: int, walked: Array[Vector2i]) -> void:
	unit_id = left_unit_id
	path = walked.duplicate()
