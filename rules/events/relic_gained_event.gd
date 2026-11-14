class_name RelicGainedEvent
extends BattleEvent
## 陣営が聖遺物を受け取った（docs/relic-buff.md）。中ボスの MidBossDefeatedEvent のすぐあとに続く。
##
## bonus は聖遺物が足す量（Unit.Stat -> int）。unit_ids は効果の掛かった駒（その陣営の、盤にいる駒すべて。番号の順）。
## max_hp・hp・power は、掛かったあとの実効値（駒の番号 -> 値）。
## ult_gain は必殺技のゲージに実際にたまった量、ult_gauge はたまったあとのゲージ（Ults.GAUGE_MAX がいっぱい）。

var side: Unit.Side
var relic: Relics.Id
var boss_index: int
var bonus: Dictionary
var unit_ids: Array[int] = []
var max_hp: Dictionary[int, int] = {}
var hp: Dictionary[int, int] = {}
var power: Dictionary[int, int] = {}
var ult_gain: int
var ult_gauge: int


func _init(
	gained_side: Unit.Side, gained_relic: Relics.Id, index: int, affected: Array[Unit], gauge_gain: int, gauge: int
) -> void:
	side = gained_side
	relic = gained_relic
	boss_index = index
	bonus = Relics.bonus(gained_relic)
	for unit in affected:
		unit_ids.append(unit.id)
		max_hp[unit.id] = unit.max_hp()
		hp[unit.id] = unit.hp
		power[unit.id] = unit.power()
	ult_gain = gauge_gain
	ult_gauge = gauge
