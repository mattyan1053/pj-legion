class_name CutWaitEvent
extends BattleEvent
## 台本の出来事（カットシーン）: 何もせずに seconds 秒待つ（間を置く）。

var seconds: float


func _init(wait_seconds: float) -> void:
	seconds = wait_seconds
