class_name UnitEvolvedEvent
extends BattleEvent
## 駒が進化した。evolution は選んだ進化先。
##
## max_hp・hp・power・move_range・attack_range は進化したあとの実効値
## （最大 HP が伸びたぶんだけ、いまの HP も増えている）。

var unit_id: int
var evolution: Evolution.Id
var max_hp: int
var hp: int
var power: int
var move_range: int
var attack_range: int


func _init(evolved: Unit) -> void:
	unit_id = evolved.id
	evolution = evolved.evolution
	max_hp = evolved.max_hp()
	hp = evolved.hp
	power = evolved.power()
	move_range = evolved.move_range()
	attack_range = evolved.attack_range()
