class_name LevelUpEvent
extends BattleEvent
## 駒のレベルが 1 つ上がった。level は上がったあとのレベル。
##
## gains は伸びた量（Unit.Stat -> int）。max_hp・hp・power は伸びたあとの実効値
## （最大 HP が伸びたぶんだけ、いまの HP も増えている）。experience は繰り越したあとにためている経験値。
## 1 回の経験値で 2 つ上がるときは、レベルごとに 1 つずつ続く。

var unit_id: int
var level: int
var gains: Dictionary
var max_hp: int
var hp: int
var power: int
var experience: int


func _init(grown: Unit, grown_by: Dictionary) -> void:
	unit_id = grown.id
	level = grown.level
	gains = grown_by.duplicate()
	max_hp = grown.max_hp()
	hp = grown.hp
	power = grown.power()
	experience = grown.experience
