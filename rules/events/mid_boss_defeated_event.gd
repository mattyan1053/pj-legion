class_name MidBossDefeatedEvent
extends BattleEvent
## 中ボス（エリートミニオン）が倒れた（docs/neutral-mid-boss.md）。同じ駒の UnitDefeatedEvent のすぐあとに続く。
## 倒した（止めを刺した）のは slayer_id の駒で、その持ち主 slayer_side が「倒した陣営」になる。
## 止めを刺した駒がいない（中立の駒の攻撃など。いまのルールでは起きない）ときは、slayer_id = 0、slayer_side = -1。
## 中ボスは湧き直さない。聖遺物（relic-buff）は、このイベントの倒した陣営に入る。

## 中ボスの番号（Board.mid_boss_cells の添字。0 = 左、1 = 右）。
var boss_index: int
var unit_id: int
var cell: Vector2i
var slayer_id: int
var slayer_side: int


func _init(index: int, boss: Unit, slayer: Unit) -> void:
	boss_index = index
	unit_id = boss.id
	cell = boss.cell
	slayer_id = slayer.id if slayer != null else 0
	slayer_side = slayer.side if slayer != null else -1
