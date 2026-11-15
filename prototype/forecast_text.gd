extends RefCounted
## 戦闘予測（Forecast）を、画面に出す形に直す。ルールは持たない（Forecast をそのまま読む。計算を二重に持たない）。ノードに依存しない。
##
## - summarize(): 予測のパネル（forecast_panel.gd）に出す、駒ごとの行と、駒に属さない行。
## - describe(): 同じものを文にしたもの（1 行ずつ）。

const BattleHud := preload("res://prototype/battle_hud.gd")
const Names := preload("res://prototype/names.gd")


## 予測のパネルの 1 行（何かが起きる駒 1 体ぶん）。
class Row:
	extends RefCounted
	var unit_id := 0
	var name := ""
	var side := Unit.Side.PLAYER1
	## 行動する駒自身か（爆発に巻き込まれるときの警告に使う）。
	var is_actor := false
	var hp_before := 0
	var hp_after := 0
	var max_hp := 0
	## 受けるダメージ（防がれたぶんは 0）。当たらなければ -1。
	var damage := -1
	var defeated := false
	var healed := 0
	## ダメージの内訳（クリティカル、森、爆発）と、防がれた理由（バリア、煙幕）。
	var notes: Array[String] = []
	## 防がれて 0 ダメージか（バリア・煙幕）。
	var blocked := false
	## ほかに起きること（状態、移る先、もう一度行動、経験とレベルアップ・進化）。
	var effects: Array[String] = []


## 予測のパネルの中身。
class Summary:
	extends RefCounted
	var rows: Array[Row] = []
	## 駒に属さないこと（置かれる効果、盾、聖遺物、必殺技のゲージ、決着）。
	var lines: Array[String] = []
	## 行動する駒自身がダメージを受けるか（樽の爆発など）。パネルで目立たせる。
	var hurts_actor := false
	## 倒れる駒の数（行動する駒自身を除く）。
	var defeats := 0
	## 決着するか（勝ち・引き分け）。lines にも書く。
	var decides := false


## 行動の見込み（戦闘予測）を、駒ごとの行と、駒に属さない行に分ける。どの行動にも同じ読み方を使う。
## viewer は、必殺技のゲージの変わり方を出すプレイヤー（ふつうは行動する駒の持ち主）。
static func summarize(battle: Battle, forecast: Forecast, actor: Unit) -> Summary:
	var summary := Summary.new()
	for placed in forecast.placed:
		var line: String = "%s を置く" % Names.FIELD_EFFECT_NAMES[placed.type]
		if placed.cells.size() > 1:
			var inside := 0
			for unit in battle.units:
				if unit.side == actor.side and placed.cells.has(unit.cell):
					inside += 1
			line += "（中の味方 %d 体）" % inside
		summary.lines.append(line)
	for outcome in forecast.units:
		var unit := battle.unit_by_id(outcome.unit_id)
		if unit == null:
			continue
		var row := Row.new()
		row.unit_id = unit.id
		row.name = unit.display_name()
		row.side = unit.side
		row.is_actor = unit == actor
		row.hp_before = outcome.hp_before
		row.hp_after = outcome.hp_after
		row.max_hp = outcome.max_hp_after
		row.defeated = outcome.defeated
		row.healed = outcome.healed
		if outcome.smoked:
			row.damage = 0
			row.blocked = true
			row.notes.append("煙幕に阻まれる（隣からなら当たる）")
		elif outcome.blocked_by != -1 and outcome.damage == 0:
			var shield := Status.display_name(outcome.blocked_by as Status.Type)
			row.damage = 0
			row.blocked = true
			row.notes.append("%s が防ぐ（%s は消える）" % [shield, shield])
		elif outcome.hits > 0:
			row.damage = outcome.damage
			if outcome.critical:
				row.notes.append("クリティカル")
			if outcome.forest:
				row.notes.append("森で軽減")
			if outcome.exploded:
				row.notes.append("爆発")
			if row.is_actor:
				summary.hurts_actor = true
		if row.defeated and not row.is_actor:
			summary.defeats += 1
		for status: int in outcome.statuses_applied:
			row.effects.append("%s が付く（%d ターン）" % [Status.display_name(status as Status.Type), outcome.statuses_applied[status]])
		for status in outcome.statuses_removed:
			if status != outcome.blocked_by:
				row.effects.append("%s が解ける" % Status.display_name(status as Status.Type))
		if outcome.moved_to != Board.NO_CELL:
			row.effects.append("(%d, %d) へ移る" % [outcome.moved_to.x, outcome.moved_to.y])
		if outcome.reactivated:
			row.effects.append("もう一度行動できる")
		if outcome.experience > 0:
			var growth := ""
			if outcome.evolution_ready:
				var names: Array[String] = []
				for choice in Evolution.options_for(unit.kind):
					names.append(Evolution.display_name(choice))
				growth = "　レベルアップ → 進化を選べる（%s）" % " / ".join(names)
			elif outcome.levels_gained > 0:
				growth = "　レベルアップ（Lv%d）" % (unit.level + outcome.levels_gained)
			row.effects.append("経験 +%d%s" % [outcome.experience, growth])
		summary.rows.append(row)
	for barricade in forecast.barricades:
		summary.lines.append("盾: 耐久 %d → %s" % [
			barricade.durability_before, "壊れる" if barricade.destroyed else str(barricade.durability_after),
		])
	for relic in forecast.relics:
		summary.lines.append("聖遺物「%s」を得る（%s）" % [Relics.display_name(relic.relic), Relics.summary(relic.relic)])
	if actor != null and actor.side != Unit.Side.NEUTRAL:
		var side := actor.side
		var before := _percent(forecast.gauge_before[side])
		var after := _percent(forecast.gauge_after[side])
		if forecast.accepted and after != before and Ults.of(battle, side) != null:
			summary.lines.append("必殺技のゲージ %d%% → %d%%" % [before, mini(after, 100)])
	if forecast.drawn:
		summary.lines.append("引き分けになる")
		summary.decides = true
	elif forecast.winner != -1:
		summary.lines.append("%s の勝ち" % Names.SIDE_NAMES[forecast.winner])
		summary.decides = true
	return summary


## 必殺技のゲージを、100 をいっぱいとした値で（Ults.percent と同じ切り捨て）。
static func _percent(gauge: int) -> int:
	@warning_ignore("integer_division")
	return gauge * 100 / Ults.GAUGE_MAX


## 1 体ぶんの HP の行（「N ダメージ → 残り HP X」「倒れる」「+N → HP X / Y」）。ダメージも回復も無ければ空。
static func hp_text(row: Row) -> String:
	if row.damage >= 0:
		if row.blocked:
			return "0 ダメージ"
		return "%d ダメージ → %s" % [row.damage, "倒れる" if row.defeated else "残り HP %d" % row.hp_after]
	if row.healed > 0:
		return "+%d → HP %d / %d" % [row.healed, row.hp_after, row.max_hp]
	return ""


## 行動の見込み（戦闘予測）を、駒ごとの行に並べた文。何も起きなければ「何も起きない」。
static func describe(battle: Battle, forecast: Forecast, actor: Unit) -> String:
	var summary := summarize(battle, forecast, actor)
	var lines: Array[String] = []
	for row in summary.rows:
		var name := "自分" if row.is_actor else row.name
		var hp := hp_text(row)
		if hp != "":
			var notes := " ".join(row.notes)
			lines.append("%s: %s%s" % [name, (notes + " ") if notes != "" else "", hp])
		for effect in row.effects:
			lines.append("%s: %s" % [name, effect])
	lines.append_array(summary.lines)
	if lines.is_empty():
		lines.append("何も起きない")
	return "\n".join(lines)
