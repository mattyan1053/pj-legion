class_name CutCameraEvent
extends BattleEvent
## 台本の出来事（カットシーン）: カメラを、マス cell の上へ寄せる。

var cell: Vector2i


func _init(at: Vector2i) -> void:
	cell = at
