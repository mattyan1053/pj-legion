class_name AttackBarrelAction
extends BattleAction
## 駒がいまの位置から、射程内の起爆樽を攻撃する。樽は爆発して消え、攻撃した駒は行動を終える。
##
## 爆発は周り 8 マスの駒すべて（敵・味方・中立、攻撃した駒自身も）に固定のダメージを与える。
## 駒への攻撃と同じく、動かずに攻撃してもよく、巡航で動いた駒は攻撃できない。

var unit_id: int
var cell: Vector2i


func _init(attacker_id: int, barrel_cell: Vector2i) -> void:
	unit_id = attacker_id
	cell = barrel_cell


func is_valid(battle: Battle) -> bool:
	var attacker := battle.unit_by_id(unit_id)
	if not battle.can_act(attacker) or attacker.cruised:
		return false
	return MapObject.can_attack_barrel(battle, attacker, cell)


func execute(battle: Battle) -> Array[BattleEvent]:
	var attacker := battle.unit_by_id(unit_id)
	var victims := MapObject.blast_victims(battle, cell)
	var victim_ids: Array[int] = []
	for victim in victims:
		victim_ids.append(victim.id)
	var events: Array[BattleEvent] = [
		BarrelExplodedEvent.new(attacker.id, cell, MapObject.blast_cells(battle.board, cell), victim_ids)
	]
	battle.board.remove_barrel(cell)
	# 爆発は同時に当たる。全員のダメージを先に並べ、倒れた駒はそのあとにまとめて取り除く。
	# バリアで防いだ駒の状態が外れるイベントは、全員のダメージのあとに並べる。
	var after: Array[BattleEvent] = []
	for victim in victims:
		var hit := MapObject.blast_hit(victim)
		after.append_array(hit.apply())
		events.append(ExplosionDamagedEvent.new(cell, hit))
	events.append_array(after)
	events.append_array(Statuses.after_attack(attacker))
	for victim in victims:
		if victim.hp == 0:
			events.append(battle.remove_unit(victim))
	# 攻撃した駒が自分の爆発で倒れたら、行動を終えるイベントは出ない。
	if battle.units.has(attacker):
		events.append(battle.finish_action(attacker))
	return events
