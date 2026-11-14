extends RefCounted
## 戦闘予測（Forecast）を、画面の左下に出す文に直す。ルールは持たない。ノードに依存しない。

const BattleHud := preload("res://prototype/battle_hud.gd")


## 行動の見込み（戦闘予測）を、駒ごとの行に並べる。どの行動にも同じ読み方を使う
## （ダメージと残りの HP、防がれるか、回復、状態、移る先、経験値、置かれる効果、盾、聖遺物、決着）。
static func describe(battle: Battle, forecast: Forecast, actor: Unit) -> String:
	var lines: Array[String] = []
	for placed in forecast.placed:
		var line: String = "%s を置く" % BattleHud.FIELD_EFFECT_NAMES[placed.type]
		if placed.cells.size() > 1:
			var inside := 0
			for unit in battle.units:
				if unit.side == actor.side and placed.cells.has(unit.cell):
					inside += 1
			line += "（中の味方 %d 体）" % inside
		lines.append(line)
	for outcome in forecast.units:
		var unit := battle.unit_by_id(outcome.unit_id)
		if unit == null:
			continue
		var name := "自分" if unit == actor else unit.display_name()
		if outcome.smoked:
			lines.append("%s: 煙幕に阻まれて 0 ダメージ（隣からなら当たる）" % name)
		elif outcome.blocked_by != -1 and outcome.damage == 0:
			var shield := Status.display_name(outcome.blocked_by as Status.Type)
			lines.append("%s: %s に防がれて 0 ダメージ（%s は消える）" % [name, shield, shield])
		elif outcome.hits > 0:
			var notes := ""
			if outcome.critical:
				notes += "クリティカル "
			if outcome.forest:
				notes += "森で軽減 "
			if outcome.exploded:
				notes += "爆発 "
			lines.append("%s: %s%d ダメージ → %s" % [
				name, notes, outcome.damage, "倒れる" if outcome.defeated else "残り HP %d" % outcome.hp_after,
			])
		if outcome.healed > 0:
			lines.append("%s: +%d → HP %d / %d" % [name, outcome.healed, outcome.hp_after, outcome.max_hp_after])
		for status: int in outcome.statuses_applied:
			lines.append("%s に %s（%d ターン）" % [name, Status.display_name(status as Status.Type), outcome.statuses_applied[status]])
		for status in outcome.statuses_removed:
			if status != outcome.blocked_by:
				lines.append("%s の %s が解ける" % [name, Status.display_name(status as Status.Type)])
		if outcome.moved_to != Board.NO_CELL:
			lines.append("%s は (%d, %d) へ移る" % [name, outcome.moved_to.x, outcome.moved_to.y])
		if outcome.reactivated:
			lines.append("%s がもう一度行動できる" % name)
		if outcome.experience > 0:
			var growth := ""
			if outcome.evolution_ready:
				growth = "（レベルアップ。進化できる）"
			elif outcome.levels_gained > 0:
				growth = "（レベルアップ）"
			lines.append("%s: 経験 +%d%s" % [name, outcome.experience, growth])
	for barricade in forecast.barricades:
		lines.append("盾: 耐久 %d → %s" % [
			barricade.durability_before, "壊せる" if barricade.destroyed else str(barricade.durability_after),
		])
	for relic in forecast.relics:
		lines.append("聖遺物「%s」を得る" % Relics.display_name(relic.relic))
	if forecast.drawn:
		lines.append("引き分けになる")
	elif forecast.winner != -1:
		lines.append("%s の勝ち" % BattleHud.SIDE_NAMES[forecast.winner])
	if lines.is_empty():
		lines.append("何も起きない")
	return "\n".join(lines)
