extends CpuPlayer
## 測るための版（--rival に渡す。docs/relic-buff.md の「受け取る」）: 中ボスを自分からは削らず、相手が削った中ボスの止めだけを狙う CPU。
## 「削らずに待って、止めだけ取る」が、遊ぶ人にとって得な手かを見る。
## - 中ボスを狩らない（削る手は、いまの CPU の「狩ると決めていない中ボス」と同じに減点する。向かいもしない）。
## - 相手が削り始めた中ボスへは、HP がいくつでも、後衛と奇襲が止めを横取りしに向かう（いまの CPU は最大 HP の半分から）。
## - 止めを刺せる手は、いまの CPU と同じに高く見る（_mid_boss_damage_value。倒す価値は聖遺物の価値）。
## ほかは、いまの CPU（CpuPlayer）と同じ。
##
##   godot --headless --path . -s res://tools/cpu_matches.gd -- --games=240 --pairings=mixed --rival=res://tools/rivals/finish_only.gd


func _build_hunts() -> void:
	if _hunts_ready:
		return
	super._build_hunts()
	_hunted = {}
	_chipped = {}


func _boss_to_steal(unit: Unit) -> Unit:
	_build_hunts()
	var best: Unit = null
	var best_distance := DENY_RADIUS + 1
	for boss_id in _rival_hunts:
		var boss := _battle.unit_by_id(boss_id)
		var apart := Combat.distance(unit.cell, boss.cell)
		if apart < best_distance:
			best = boss
			best_distance = apart
	return best
