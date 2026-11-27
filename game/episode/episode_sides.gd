extends "res://game/episode/episode_base.gd"
## 話（game/episode.gd）の、陣営の節 [ally] と [enemy] を読む: 駒の行、成長、軍略と誓い、初期位置、将のいない話の確かめ。


## 陣営の節（[ally] = 人の軍、[enemy] = 敵の軍）。
func _read_side(file: RefCounted, section: String, side: int) -> void:
	if not file.has(section):
		# 人の側は、書かなければ「出撃準備で選んだ部隊を、いつもの初期位置に」。敵の側は、軍と部隊が要る。
		if side == 1:
			file.problem(1, "[enemy] の節が無い（敵の軍 army と、部隊 unit を書く）")
		return
	var keys := ["unit", "deploy", "trait", "oath"]
	keys.append_array(["start_gauge"] if side == 0 else ["army", "king_figure", "king", "spare_boss"])
	var values: Dictionary = file.values(section, keys, ["unit", "deploy", "oath"])
	_read_trait(file, values, side)
	if values.has("king_figure"):
		var entry: Dictionary = values["king_figure"][0]
		var king_look := StringName(entry["value"])
		if UnitLooks.KING_LOOKS.has(king_look):
			king_looks[side] = king_look
		else:
			file.problem(entry["line"], "知らない将の姿「%s」（書けるのは %s）" % [king_look, ", ".join(UnitLooks.KING_LOOKS)])
	var rows: Array = []
	var grown: Array = []
	for entry: Dictionary in values.get("unit", []):
		var row := _unit_row(file, entry)
		if not row.is_empty():
			rows.append(row)
			grown.append(_growth_of(file, entry, row[0]))
	growth[side] = grown
	var cells: Array[Vector2i] = []
	for entry: Dictionary in values.get("deploy", []):
		cells.append_array(file.cells(entry))
	deploy[side] = cells
	_deploy_lines[side] = values["deploy"][0]["line"] if values.has("deploy") else file.line_of(section)
	if side == 0:
		squad = rows
		if rows.size() > Deck.MAX_UNITS:
			file.problem(file.line_of(section), "決まっている部隊は %d 体まで（いま %d 体）" % [Deck.MAX_UNITS, rows.size()])
		if values.has("start_gauge"):
			var entry: Dictionary = values["start_gauge"][0]
			start_gauge = file.integer(entry)
			if start_gauge < 1 or start_gauge > Ults.GAUGE_MAX:
				file.problem(entry["line"], "start_gauge は 1 から %d" % Ults.GAUGE_MAX)
				start_gauge = 0
		return
	enemy = rows
	if values.has("king"):
		var entry: Dictionary = values["king"][0]
		if entry["value"] != "none":
			file.problem(entry["line"], "king に書けるのは none（将のいない群れ）だけ")
		else:
			enemy_king = false
			if values.has("king_figure"):
				file.problem(values["king_figure"][0]["line"], "将のいない敵（king = none）に、将の姿（king_figure）は書けない")
	if values.has("spare_boss"):
		var entry: Dictionary = values["spare_boss"][0]
		if entry["value"] != "yes":
			file.problem(entry["line"], "spare_boss に書けるのは yes（敵の側は番人を狙わない）だけ")
		else:
			enemy_spares_boss = true
	if rows.is_empty():
		file.problem(file.line_of(section), "敵の部隊（unit）が無い")
	if not values.has("army"):
		file.problem(file.line_of(section), "[enemy] に army が無い")
	else:
		var entry: Dictionary = values["army"][0]
		var army := StoryFile.enum_value(UnitKind.Army, entry["value"])
		if army < 0:
			file.problem(entry["line"], "知らない軍「%s」（書けるのは %s）" % [entry["value"], StoryFile.enum_words(UnitKind.Army)])
		else:
			enemy_army = army as UnitKind.Army
			# 軍の無い敵に軍の駒を混ぜると、盤に置いたときにその駒の軍（と必殺技）が付く（Battle.add_unit）。混ぜさせない。
			if enemy_army == UnitKind.Army.NONE:
				for unit_entry: Dictionary in values.get("unit", []):
					var kind := StoryFile.enum_value(UnitKind.Id, (unit_entry["value"] as String).split(",")[0].split("+")[0])
					if kind >= 0 and UnitKind.army(kind as UnitKind.Id) != UnitKind.Army.NONE:
						file.problem(unit_entry["line"], "軍の無い敵（army = none）に、軍の駒は置けない: %s" % UnitKind.Id.keys()[kind].to_lower())


## 陣営の軍略（trait）と誓いの組（oath。trait = oath のときだけ。「1, 2」の形で、unit の行を 1 から数えた番号）。
## 軍に合うかは、両方の陣営を読んだあと（_check_traits）に確かめる。
func _read_trait(file: RefCounted, values: Dictionary, side: int) -> void:
	if values.has("trait"):
		var entry: Dictionary = values["trait"][0]
		var chosen := Traits.from_key(entry["value"])
		if chosen == Traits.NONE:
			file.problem(entry["line"], "知らない軍略「%s」（書けるのは %s）" % [entry["value"], StoryFile.enum_words(Traits.Id)])
		else:
			traits[side] = chosen
	var pairs: Array = []
	for entry: Dictionary in values.get("oath", []):
		if traits[side] != Traits.Id.OATH:
			file.problem(entry["line"], "oath は trait = oath の陣営だけ")
			continue
		var parts := (entry["value"] as String).split(",")
		if parts.size() != 2 or not parts[0].strip_edges().is_valid_int() or not parts[1].strip_edges().is_valid_int():
			file.problem(entry["line"], "oath は「1, 2」の形（unit の行を 1 から数えた番号）")
			continue
		var a := parts[0].strip_edges().to_int() - 1
		var b := parts[1].strip_edges().to_int() - 1
		var rows := values.get("unit", []).size() as int
		if a < 0 or b < 0 or a >= rows or b >= rows or a == b:
			file.problem(entry["line"], "oath の番号が unit の行に無い（1〜%d の、違う 2 つ）" % rows)
			continue
		if pairs.any(func(pair: Vector2i) -> bool: return pair.x in [a, b] or pair.y in [a, b]):
			file.problem(entry["line"], "1 体は 1 組まで")
			continue
		pairs.append(Vector2i(mini(a, b), maxi(a, b)))
	if pairs.size() > Traits.MAX_OATHS:
		file.problem(values["oath"][0]["line"], "誓いは %d 組まで" % Traits.MAX_OATHS)
		pairs.resize(Traits.MAX_OATHS)
	oaths[side] = pairs


## 陣営の軍略が、その陣営の軍のものか（人の側は、部隊が決まっている話なら、その部隊の軍。決まっていなければ物語の軍で、ここでは見ない）。
## 両方の陣営の節を読んだあとに読む。
func _check_traits(file: RefCounted) -> void:
	var armies: Array = [UnitKind.army(squad[0][0]) if not squad.is_empty() else -1, enemy_army]
	for side in 2:
		if traits[side] != Traits.NONE and armies[side] != -1 and not Traits.of_army(armies[side]).has(traits[side]):
			file.problem(file.line_of("ally" if side == 0 else "enemy"), "軍略「%s」はこの陣営の軍の軍略ではない" % Traits.key(traits[side]))
	if traits[0] == Traits.Id.OATH and squad.is_empty():
		file.problem(file.line_of("ally"), "人の側の誓いは、部隊が決まっている話（unit を書いた [ally]）だけ")


## 駒の行（「paladin + iron_shield + iron_shield」）を [駒の種類, [装備, …]] に。読めなければ空。
## 「,」のあとの始めのレベルと経験値（「sorcerer, level 2, exp 100」）は _growth_of が読む。
func _unit_row(file: RefCounted, entry: Dictionary) -> Array:
	var words := (entry["value"] as String).split(",")[0].split("+")
	var kind := _kind(file, entry, words[0])
	var items: Array[Equipment.Id] = []
	for i in range(1, words.size()):
		var item := _item(file, entry, words[i])
		if item >= 0:
			items.append(item as Equipment.Id)
	if kind < 0:
		return []
	if not items.is_empty() and not Equipment.can_equip(kind as UnitKind.Id):
		file.problem(entry["line"], "%s は持ち物を持てない（軍に属する駒だけが持てる）" % words[0].strip_edges())
		return []
	if not Equipment.is_valid_for(kind as UnitKind.Id, items):
		file.problem(entry["line"], "%s はこの持ち物の組を持てない（役割の限り、1 体の数、重ねられない持ち物）" % words[0].strip_edges())
		return []
	return [kind, items]


## 駒の行の「,」のあと（「level 2」「exp 100」。どちらも無くてよい）を [レベル, 経験値] に。無ければ [1, 0]。
## レベルは 1 から Growth.MAX_LEVEL - 1（進化は対戦の中で選ぶ）、経験値は 0 から Growth.EXPERIENCE_PER_LEVEL - 1。
func _growth_of(file: RefCounted, entry: Dictionary, kind: int) -> Array:
	var result := [1, 0]
	var parts := (entry["value"] as String).split(",")
	for i in range(1, parts.size()):
		var words := parts[i].strip_edges().split(" ", false)
		var at := ["level", "exp"].find(words[0] if words.size() == 2 else "")
		if at < 0 or not words[1].is_valid_int():
			file.problem(entry["line"], "駒の行の「,」のあとは「level 数」か「exp 数」: %s" % parts[i].strip_edges())
			continue
		result[at] = words[1].to_int()
	if result == [1, 0]:
		return result
	if not Growth.GAINS.has(UnitKind.role(kind as UnitKind.Id)):
		file.problem(entry["line"], "%s は育たない（レベルと経験値は書けない）" % parts[0].strip_edges())
		return [1, 0]
	if result[0] != Growth.start_level(result[0]):
		file.problem(entry["line"], "level は 1 から %d（進化は対戦の中で選ぶ）" % (Growth.MAX_LEVEL - 1))
	if result[1] != Growth.start_experience(result[1]):
		file.problem(entry["line"], "exp は 0 から %d" % (Growth.EXPERIENCE_PER_LEVEL - 1))
	return [Growth.start_level(result[0]), Growth.start_experience(result[1])]


## 駒の種類（将は書けない）。読めなければ -1。
func _kind(file: RefCounted, entry: Dictionary, word: String) -> int:
	var kind := StoryFile.enum_value(UnitKind.Id, word)
	if kind < 0 or kind == UnitKind.Id.KING:
		file.problem(entry["line"], "知らない駒「%s」（書けるのは %s）" % [word.strip_edges(), StoryFile.enum_words(UnitKind.Id, [UnitKind.Id.KING])])
		return -1
	return kind


func _item(file: RefCounted, entry: Dictionary, word: String) -> int:
	var item := StoryFile.enum_value(Equipment.Id, word)
	if item < 0:
		file.problem(entry["line"], "知らない持ち物「%s」（書けるのは %s）" % [word.strip_edges(), StoryFile.enum_words(Equipment.Id)])
	return item


## 将のいない群れ（king = none）の話の矛盾: 人の勝ち方（wins）を書かない（いつもの勝ち方は将の撃破と本陣の占拠）、
## 将の撃破か本陣の占拠を勝ち方に入れた（倒す将がいない。空の本陣に乗るだけで勝ててしまう）、
## 敵の話し手の姿が将（figure を書かないときも）、敵の将の HP のきっかけ。
func _check_kingless(file: RefCounted) -> void:
	if enemy_king:
		return
	var line: int = file.line_of("enemy")
	if wins.is_empty():
		file.problem(line, "将のいない敵（king = none）の話は、人の勝ち方（wins）を書く（routed, boss_slain, turns_held から）")
	for reason: GameWonEvent.Reason in [GameWonEvent.Reason.KING_DEFEATED, GameWonEvent.Reason.HQ_CAPTURED]:
		if wins.has(reason):
			file.problem(file.line_of("episode"), "将のいない敵（king = none）の話の wins に、%s は書けない" % String(GameWonEvent.Reason.find_key(reason)).to_lower())
	for i in speakers.size():
		if speaker_sides[i] == 1 and figures[i]["kind"] == UnitKind.Id.KING:
			file.problem(line, "将のいない敵（king = none）の話し手「%s」に、[cast] で将でない姿を書く（「名前 = enemy, skeleton_caller」など）" % speakers[i])
	for cue in cues:
		if cue.trigger == BattleCues.KING_HALF and cue.value == 1:
			file.problem(file.line_of("cues"), "将のいない敵（king = none）に、敵の将の HP のきっかけ（king_half enemy）は書けない")


## 初期位置: 歩けて、物が無く、本陣でなく、重ならず、数が足りる。
func _check_deploy(file: RefCounted) -> void:
	if map == null:
		return
	var board := map.make_board()
	var seen := {}
	for side: int in [0, 1]:
		var section := "ally" if side == 0 else "enemy"
		var at: int = _deploy_lines[side]
		for cell: Vector2i in deploy[side]:
			if not board.is_walkable(cell) or board.object_at(cell) != MapObject.Type.NONE or board.hq_cells.has(cell):
				file.problem(at, "[%s] の初期位置 %d,%d に置けない（歩けないマス、物、本陣、盤の外）" % [section, cell.x, cell.y])
			elif seen.has(cell):
				file.problem(at, "初期位置 %d,%d が重なっている" % [cell.x, cell.y])
			seen[cell] = true
	var enemy_cells: Array = deploy[1]
	if not enemy_cells.is_empty() and enemy_cells.size() < enemy.size():
		file.problem(_deploy_lines[1], "敵の初期位置（%d）が、敵の部隊の数（%d）より少ない" % [enemy_cells.size(), enemy.size()])
	var ally_cells: Array = deploy[0]
	var needed := squad.size() if has_squad() else Deck.MAX_UNITS
	if not ally_cells.is_empty() and ally_cells.size() < needed:
		file.problem(_deploy_lines[0], "人の初期位置（%d）が、部隊の数の上限（%d）より少ない" % [ally_cells.size(), needed])
