class_name CutPaceEvent
extends BattleEvent
## 台本の出来事（カットシーン）: このあと歩く兵の、1 マスの秒数を変える（カットシーンの終わりまで）。

var step_time: float


func _init(seconds_per_step: float) -> void:
	step_time = seconds_per_step
