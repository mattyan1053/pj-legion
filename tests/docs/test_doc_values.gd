extends "res://tests/base_test.gd"
## 文書（docs/）に書いた調整値が、コードの値と一致すること（docs/README.md の「置き方」）。
##
## 3 つの形で突き合わせる。どれも、文書はふつうの表と文のままで読む（機械のための印は要らない）。
## - 表: 「いま」「いまの値」の列を持つ表は、同じ行に `Class.NAME` か `NAME` があれば、「いま」の列の先頭の数を、その定数と比べる。
##   行に定数が 2 つあれば、前から順に 2 つの数と比べる。
## - 文: 「14 歩（`HUNT_RADIUS`）」のように、数のすぐあとの括弧の先頭に定数を書いたものは、その数を定数と比べる。
## - 個別: 定数を名指ししない表（駒の種類の表、進化先の表など）は、下のテストが行ごとに、コードから引いた値と比べる。
##
## `NAME` は、その文書の挙げる `rules/....gd` から探し、無ければ rules/ の下の全部から探す。`Class.NAME` は class_name で引く。
## 数でない定数（表や並び）は比べない。文書の挙げる定数がコードに無ければ失敗にする（名前が変わったのに文書が古い）。
## 失敗は「どの文書の何行目の、どの行のどの列が、文書ではいくつ、コードではいくつ」で出る。
## 文書とコードが食い違ったら、コードが正で、文書を直す。

const Names := preload("res://game/names.gd")
const DocTables := preload("res://tests/support/doc_tables.gd")

## 自動で突き合わせる表の「いま」の列の見出し。
const VALUE_HEADERS: Array[String] = ["いま", "いまの値"]
## 定数とみなす `` の中身: `NAME` か `Class.NAME`（NAME は大文字と _ と数字）。
const CONSTANT_PATTERN := "^(?:([A-Z][A-Za-z0-9]*)\\.)?([A-Z][A-Z0-9_]*)$"
## 文の中の「数（`定数`」。数と括弧の間には、単位（歩、マス、倍、% など）だけを挟める。
const PROSE_PATTERN := "([+\\-−]?\\d+(?:\\.\\d+)?)[^\\d（）`|、。]{0,6}（`(?:([A-Z][A-Za-z0-9]*)\\.)?([A-Z][A-Z0-9_]*)`[）、。]"

var _tables_by_path := {}


# ---- 自動: 定数を名指しした調整値の表 ----


func test_tables_that_name_constants_match_the_code() -> void:
	var checked := 0
	var regex := RegEx.create_from_string(CONSTANT_PATTERN)
	for path: String in DocTables.documents():
		var scripts := _scripts_named_in(path)
		for table: DocTables.Table in _tables(path):
			var value_column := -1
			for header in VALUE_HEADERS:
				if table.column(header) != -1:
					value_column = table.column(header)
			if value_column == -1:
				continue
			for cells: PackedStringArray in table.rows:
				var expected: Array[float] = []
				var names: Array[String] = []
				for cell: String in cells:
					for span: String in DocTables.code_spans(cell):
						var found := regex.search(span)
						if found == null:
							continue
						var resolved := _resolve(found.get_string(1), found.get_string(2), scripts)
						if resolved.has("error"):
							_fail("%s「%s」の行: %s" % [table.where(), cells[0], resolved["error"]], "")
							continue
						var value: Variant = resolved["value"]
						if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
							expected.append(float(value))
							names.append(span)
				if expected.is_empty():
					continue
				var written := DocTables.numbers(cells[value_column] if value_column < cells.size() else "")
				for i in expected.size():
					checked += 1
					var doc_value: Variant = written[i] if i < written.size() else null
					_expect(doc_value, expected[i], "%s「%s」の行の「%s」（%s）" % [table.where(), cells[0], table.headers[value_column], names[i]])
	# 表を読めていないのに通る、を防ぐ。
	assert_true(checked >= 40, "自動で突き合わせた値が少なすぎる（%d）" % checked)


func test_numbers_tagged_with_constants_match_the_code() -> void:
	# 文の中の「14 歩（`HUNT_RADIUS`）」「0.8 倍（`HUNT_SUPERIORITY`）」のように、数のすぐあとの括弧の先頭に定数を書いたもの。
	var checked := 0
	var regex := RegEx.create_from_string(PROSE_PATTERN)
	for path: String in DocTables.documents():
		var scripts := _scripts_named_in(path)
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for index in lines.size():
			for found: RegExMatch in regex.search_all(lines[index]):
				var where := "%s:%d（%s）" % [path.trim_prefix("res://"), index + 1, found.get_string(0)]
				var resolved := _resolve(found.get_string(2), found.get_string(3), scripts)
				if resolved.has("error"):
					_fail("%s: %s" % [where, resolved["error"]], "")
					continue
				var value: Variant = resolved["value"]
				if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
					continue
				checked += 1
				_expect(DocTables.numbers(found.get_string(1))[0], float(value), where)
	assert_true(checked >= 20, "文の中で突き合わせた値が少なすぎる（%d）" % checked)


# ---- 個別: 定数を名指ししない文 ----


func test_readme_win_counts_match_the_code() -> void:
	# README は人の読む紹介なので定数を書かない。勝ち方の文の回数を、ここで定数と突き合わせる。
	var text := FileAccess.get_file_as_string("res://README.md")
	var counts := {
		"ターン終了を %d 回続ける": Battle.CAPTURE_TURNS_TO_WIN,
		"ターン終了を %d 回重ねると勝ち": Stronghold.HOLDS_TO_WIN,
	}
	for pattern: String in counts:
		var found := RegEx.create_from_string(pattern.replace("%d", "(\\d+)")).search(text)
		if found == null:
			_fail("README.md に「%s」の文が無い" % pattern, "")
			continue
		_expect(float(found.get_string(1)), float(counts[pattern]), "README.md の「%s」" % found.get_string(0))


# ---- 個別: 定数を名指ししない表 ----


func test_unit_roster_matches_unit_kind() -> void:
	var table := _table("res://docs/unit-roster.md", ["種類", "役割", "軍", "コスト"])
	if table == null:
		return
	var roles := {
		UnitKind.Role.VANGUARD: "前衛", UnitKind.Role.REARGUARD: "後衛", UnitKind.Role.RAIDER: "奇襲", UnitKind.Role.HEALER: "回復",
	}
	assert_eq(table.rows.size(), UnitKind.Id.size(), "%s の行の数（駒の種類の数）" % table.where())
	for kind: UnitKind.Id in UnitKind.Id.values():
		var name := Names.kind(kind)
		_expect_number(table, name, "コスト", UnitKind.cost(kind))
		_expect_number(table, name, "最大 HP", UnitKind.max_hp(kind))
		_expect_number(table, name, "攻撃力", UnitKind.power(kind))
		_expect_number(table, name, "移動力", UnitKind.move_range(kind))
		_expect_number(table, name, "射程", UnitKind.attack_range(kind))
		_expect_text(table, name, "役割", roles.get(UnitKind.role(kind), "-"), true)
		var army := UnitKind.army(kind)
		_expect_text(table, name, "軍", "-" if army == UnitKind.Army.NONE else UnitKind.Army.keys()[army])


func test_rosters_and_budgets_match_deck() -> void:
	var table := _table("res://docs/player-loadout.md", ["軍", "前衛", "後衛", "奇襲", "回復", "予算"])
	if table == null:
		return
	var columns := {
		UnitKind.Role.VANGUARD: "前衛", UnitKind.Role.REARGUARD: "後衛", UnitKind.Role.RAIDER: "奇襲", UnitKind.Role.HEALER: "回復",
	}
	for army: UnitKind.Army in [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]:
		var key: String = UnitKind.Army.keys()[army]
		_expect_number(table, key, "予算", Deck.budget_of(army))
		for kind: UnitKind.Id in Deck.roster(army):
			_expect_text(table, key, columns[UnitKind.role(kind)], Names.kind(kind))


func test_equipment_matches_equipment() -> void:
	var table := _table("res://docs/player-loadout.md", ["装備", "コスト"])
	if table == null:
		return
	var role_names := {
		UnitKind.Role.VANGUARD: "前衛", UnitKind.Role.REARGUARD: "後衛", UnitKind.Role.RAIDER: "奇襲", UnitKind.Role.HEALER: "回復",
	}
	for item: Equipment.Id in Equipment.Id.values():
		var name := Names.item(item)
		_expect_number(table, name, "コスト", Equipment.cost(item))
		var amount := 0
		for stat: Unit.Stat in Unit.Stat.values():
			amount += Equipment.bonus(item, stat)
		if amount != 0:  # 特性だけの装備は、数を書かない（特性の名前を書く）
			_expect_number(table, name, "効果（1 個につき）", amount)
		_expect_number(table, name, "1 体に", Equipment.stack_limit(item))
		var holders: Array[String] = []
		for role: UnitKind.Role in Equipment.roles(item):
			holders.append(role_names[role])
		_expect_text(table, name, "持てる駒", "・".join(holders) if not holders.is_empty() else "どれでも")
		_expect_text(table, name, "対戦モード", "出る" if DeckRules.VERSUS_ITEMS.has(item) else "出ない", true)


func test_experience_tables_match_growth() -> void:
	var path := "res://docs/experience-levelup.md"
	var gained := _table(path, ["出来事", "経験値"])
	if gained != null:
		_expect_number(gained, "攻撃が当たり、相手が生き残った", "経験値", Growth.HIT_EXPERIENCE)
		_expect_number(gained, "攻撃でプレイヤーの駒を倒した", "経験値", Growth.DEFEAT_EXPERIENCE)
		_expect_number(gained, "攻撃で中立の駒を倒した", "経験値", Growth.NEUTRAL_DEFEAT_EXPERIENCE)
		_expect_number(gained, "攻撃で中ボス（エリートミニオン）を倒した", "経験値", Growth.MID_BOSS_DEFEAT_EXPERIENCE)
		_expect_number(gained, "味方を回復した", "経験値", Growth.HEAL_EXPERIENCE)
	var gains := _table(path, ["役割", "最大 HP"])
	if gains != null:
		var names := {
			UnitKind.Role.VANGUARD: "前衛", UnitKind.Role.REARGUARD: "後衛", UnitKind.Role.RAIDER: "奇襲", UnitKind.Role.HEALER: "回復",
		}
		for role: UnitKind.Role in Growth.GAINS:
			_expect_number(gains, names[role], "最大 HP", Growth.GAINS[role][Unit.Stat.MAX_HP])
			_expect_number(gains, names[role], "攻撃力（回復役は回復量）", Growth.GAINS[role][Unit.Stat.POWER])


func test_evolution_routes_match_evolution() -> void:
	var table := _table("res://docs/branch-evolution.md", ["元の種類", "", "進化先"])
	if table == null:
		return
	var key_column := table.column("進化先")
	var stat_names := {
		Unit.Stat.MAX_HP: "最大 HP", Unit.Stat.POWER: "攻撃", Unit.Stat.MOVE_RANGE: "移動", Unit.Stat.ATTACK_RANGE: "射程",
	}
	assert_eq(table.rows.size(), Evolution.Id.size() - 1, "%s の行の数（進化先の数）" % table.where())
	for id: Evolution.Id in Evolution.Id.values():
		if id == Evolution.Id.NONE:
			continue
		var name := Names.evolution(id)
		var kind := Evolution.origin(id)
		var cells := table.row(name, key_column)
		if cells.is_empty():
			_fail("%s に「%s」の行が無い" % [table.where(), name], "")
			continue
		# 能力値の増減: 「最大 HP +18、移動 −1」のように、能力値の名前と量の組。回復役の攻撃は「回復」と書く。
		var written := {}
		var changes := cells[table.column("能力値の増減")]
		for part: String in changes.split("、"):
			for stat: Unit.Stat in stat_names:
				var label: String = stat_names[stat]
				if stat == Unit.Stat.POWER and UnitKind.role(kind) == UnitKind.Role.HEALER:
					label = "回復"
				if part.begins_with(label + " "):
					written[stat] = int(DocTables.numbers(part.trim_prefix(label))[0])
		var bonuses := Evolution.bonuses(id)
		var expected := {}
		for stat: Unit.Stat in bonuses:
			if bonuses[stat] != 0:
				expected[stat] = bonuses[stat]
		_expect(written, expected, "%s「%s」の行の「能力値の増減」（%s）" % [table.where(), name, changes])
		# Lv3 の値: 基本 + レベルアップ 2 回ぶん + 進化の増減（装備なし）。
		var gains: Dictionary = Growth.GAINS[UnitKind.role(kind)]
		var levels := Growth.MAX_LEVEL - 1
		var lv3: Array[float] = [
			UnitKind.max_hp(kind) + gains.get(Unit.Stat.MAX_HP, 0) * levels + Evolution.bonus(id, Unit.Stat.MAX_HP),
			UnitKind.power(kind) + gains.get(Unit.Stat.POWER, 0) * levels + Evolution.bonus(id, Unit.Stat.POWER),
			UnitKind.move_range(kind) + Evolution.bonus(id, Unit.Stat.MOVE_RANGE),
			UnitKind.attack_range(kind) + Evolution.bonus(id, Unit.Stat.ATTACK_RANGE),
		]
		var lv3_column := table.column("Lv3: HP / 攻撃 / 移動 / 射程")
		_expect(DocTables.numbers(cells[lv3_column]), lv3, "%s「%s」の行の「%s」" % [table.where(), name, table.headers[lv3_column]])


func test_healer_table_matches_unit_kind() -> void:
	var table := _table("res://docs/healer-role.md", ["種類", "回復量", "射程"])
	if table == null:
		return
	for kind: UnitKind.Id in [UnitKind.Id.MEDIC, UnitKind.Id.PRIEST]:
		_expect_number(table, Names.kind(kind), "回復量", UnitKind.power(kind))
		_expect_number(table, Names.kind(kind), "射程", UnitKind.attack_range(kind))


func test_terrain_table_matches_terrain() -> void:
	var table := _table("res://docs/game-board.md", ["地形", "入れるか", "入るのに使う移動力"])
	if table == null:
		return
	var names := {Terrain.Type.NORMAL: "平地", Terrain.Type.FOREST: "森", Terrain.Type.FONT: "結晶泉"}
	for type: Terrain.Type in names:
		_expect_number(table, names[type], "入るのに使う移動力", Terrain.move_cost(type))


func test_ult_gauge_table_matches_ults() -> void:
	# 「たまるとき」の表は、量の書き方が行ごとに違う（「減らした HP 1 につき 1」）ので、何番目の数かを決めて比べる。
	var table := _table("res://docs/tactical-ult.md", ["たまるとき"])
	if table == null:
		return
	var column := table.headers[1]
	_expect_number(table, "自分のフェーズの始め", column, Ults.PHASE_GAIN)
	_expect_number(table, "自分の駒が敵にダメージを与えた", column, Ults.DEALT_GAIN, 1)
	_expect_number(table, "自分の駒が敵からダメージを受けた", column, Ults.TAKEN_GAIN, 1)
	_expect_number(table, "自分の駒（将を除く）が倒れた", column, Ults.DEFEAT_GAIN)
	_expect_number(table, "聖遺物を受け取った（中ボスを倒した）", column, Relics.ULT_GAIN)


func test_relic_table_matches_relics() -> void:
	var table := _table("res://docs/relic-buff.md", ["聖遺物", "落とす中ボス"])
	if table == null:
		return
	var column := "効果（対戦の終わりまで）"
	_expect_number(table, "英知の聖遺物（`Relics.Id.WISDOM`）", column, Relics.WISDOM_MAX_HP)
	_expect_number(table, "勇気の聖遺物（`Relics.Id.COURAGE`）", column, Relics.COURAGE_POWER)
	_expect_number(table, "英知の聖遺物（`Relics.Id.WISDOM`）", "落とす中ボス", Relics.OF_BOSS.find(Relics.Id.WISDOM))
	_expect_number(table, "勇気の聖遺物（`Relics.Id.COURAGE`）", "落とす中ボス", Relics.OF_BOSS.find(Relics.Id.COURAGE))
	var values := _table("res://docs/relic-buff.md", ["値", "いま", "理由"])
	if values != null:
		_expect_number(values, "中ボスの HP", "いま", UnitKind.max_hp(UnitKind.Id.ELITE_MINION))


func test_mid_boss_table_matches_unit_kind() -> void:
	var table := _table("res://docs/neutral-mid-boss.md", ["値", "いまの値"])
	if table == null:
		return
	var boss := UnitKind.Id.ELITE_MINION
	_expect_number(table, "HP・攻撃力", "いまの値", UnitKind.max_hp(boss))
	_expect_number(table, "HP・攻撃力", "いまの値", UnitKind.power(boss), 1)
	_expect_number(table, "射程", "いまの値", UnitKind.attack_range(boss))
	_expect_number(table, "移動力", "いまの値", UnitKind.move_range(boss))


func test_field_effect_table_matches_field_effects() -> void:
	var table := _table("res://docs/field-effects.md", ["種類", "広さ", "入れるか"])
	if table == null:
		return
	_expect_number(table, "盾", "消えるとき", FieldEffects.BARRICADE_DURABILITY)


func test_cpu_weights_match_cpu_player() -> void:
	var table := _table("res://docs/cpu-ai.md", ["役割", "目標へ 1 マス"])
	if table == null:
		return
	var names := {
		UnitKind.Role.NONE: "将", UnitKind.Role.VANGUARD: "前衛", UnitKind.Role.REARGUARD: "後衛",
		UnitKind.Role.RAIDER: "奇襲", UnitKind.Role.HEALER: "回復",
	}
	var styles := {"将（戦える駒がいない）": CpuPlayer.LONE_KING_STYLE}
	for role: UnitKind.Role in CpuPlayer.STYLES:
		styles[names[role]] = CpuPlayer.STYLES[role]
	for key: String in styles:
		var weights: Array = styles[key]
		for i in weights.size():
			_expect_number(table, key, table.headers[i + 1], weights[i])


func test_cpu_action_values_match_cpu_player() -> void:
	# 「行動の結果の価値」の表。説明の文の中の数を、前から順に比べる。
	var table := _table("res://docs/cpu-ai.md", ["起きたこと", "価値"])
	if table == null:
		return
	var c := CpuPlayer
	_expect_numbers(table, "敵にダメージ", [c.DAMAGE_VALUE, c.KING_DAMAGE_VALUE, c.NEUTRAL_DAMAGE_VALUE, c.HUNT_DAMAGE_VALUE])
	_expect_numbers(table, "敵を倒す", [
		c.KILL_VALUE, c.KILL_VALUE_PER_COST, c.HEALER_KILL_BONUS, c.NEUTRAL_KILL_VALUE, c.RELIC_BASE_VALUE, c.RELIC_UNIT_VALUE,
	])
	_expect_numbers(table, "倒せなかった相手", [c.REMAINING_HP_PENALTY])
	_expect_numbers(table, "自分の本陣の近く（5 マス以内）の敵", [c.INTRUDER_RATE])
	_expect_numbers(table, "自分の本陣に乗っている敵", [c.OCCUPIER_RATE, c.OCCUPIER_KILL_BONUS])
	_expect_numbers(table, "味方にダメージ（樽の爆発）", [c.FRIENDLY_FIRE_RATE])
	_expect_numbers(table, "味方を回復", [c.HEAL_VALUE, c.HEAL_BASE_VALUE, c.WOUNDED_BONUS, c.KING_HEAL_BONUS])
	_expect_numbers(table, "経験値が入る", [c.EXPERIENCE_VALUE, c.LEVEL_UP_VALUE])
	_expect_numbers(table, "相手の盾を削る", [c.BARRICADE_DAMAGE_VALUE, c.BARRICADE_BREAK_VALUE])
	var near := table.row("自分の本陣の近く（5 マス以内）の敵")
	_expect(DocTables.numbers(near[0]) if not near.is_empty() else [], [float(c.DEFENSE_RADIUS)], "%s の「自分の本陣の近く」の距離" % table.where())


func test_cpu_decks_match_cpu_deck() -> void:
	var table := _table("res://docs/cpu-ai.md", ["軍", "編成", "コスト"])
	if table == null:
		return
	for army: UnitKind.Army in [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]:
		var deck := CpuDeck.build(army)
		var names: Array[String] = []
		for entry: DeckEntry in deck.entries:
			var name := Names.kind(entry.kind)
			var items: Array[String] = []
			var shields := entry.equipment.count(Equipment.Id.IRON_SHIELD)
			var boots := entry.equipment.count(Equipment.Id.SPEED_BOOTS)
			if shields > 0:
				items.append("盾 %d" % shields)
			if boots > 0:
				items.append("靴 %d" % boots)
			names.append(name + ("（%s）" % "、".join(items) if not items.is_empty() else ""))
		var key: String = UnitKind.Army.keys()[army]
		_expect_text(table, key, "編成", "、".join(names))
		_expect_text(table, key, "コスト", "%d / %d" % [deck.total_cost(), deck.budget()])


# ---- 道具 ----


func _tables(path: String) -> Array:
	if not _tables_by_path.has(path):
		_tables_by_path[path] = DocTables.read(path)
	return _tables_by_path[path]


## path の文書で、見出しが headers で始まる最初の表。無ければ失敗にして null。
func _table(path: String, headers: Array[String]) -> DocTables.Table:
	for table: DocTables.Table in _tables(path):
		if table.headers.size() < headers.size():
			continue
		var same := true
		for i in headers.size():
			if table.headers[i] != headers[i]:
				same = false
		if same:
			return table
	_fail("%s に、見出しが %s で始まる表が無い" % [path.trim_prefix("res://"), " | ".join(headers)], "")
	return null


func _cell(table: DocTables.Table, key: String, column: String) -> Variant:
	var cells := table.row(key)
	if cells.is_empty():
		_fail("%s に「%s」の行が無い" % [table.where(), key], "")
		return null
	var index := table.column(column)
	if index == -1 or index >= cells.size():
		_fail("%s に「%s」の列が無い" % [table.where(), column], "")
		return null
	return cells[index]


## 行 key・列 column のセルの、index 番目（0 から）の数が expected であること。
func _expect_number(table: DocTables.Table, key: String, column: String, expected: float, index := 0) -> void:
	var cell: Variant = _cell(table, key, column)
	if cell == null:
		return
	var written := DocTables.numbers(cell)
	_expect(written[index] if index < written.size() else null, expected, "%s「%s」の行の「%s」（%s）" % [table.where(), key, column, cell])


## 行 key の 2 列目のセルの数が、前から順に expected であること。
func _expect_numbers(table: DocTables.Table, key: String, expected: Array) -> void:
	var cell: Variant = _cell(table, key, table.headers[1])
	if cell == null:
		return
	var written := DocTables.numbers(cell)
	var want: Array[float] = []
	for value: float in expected:
		want.append(value)
	_expect(written.slice(0, want.size()), want, "%s「%s」の行の「%s」（%s）" % [table.where(), key, table.headers[1], cell])


## 行 key・列 column のセルが expected であること（starts が真なら、expected で始まること）。
func _expect_text(table: DocTables.Table, key: String, column: String, expected: String, starts := false) -> void:
	var cell: Variant = _cell(table, key, column)
	if cell == null:
		return
	if (starts and not String(cell).begins_with(expected)) or (not starts and cell != expected):
		_fail("%s「%s」の行の「%s」: 文書は「%s」、コードは「%s」" % [table.where(), key, column, cell, expected], "")


func _expect(doc_value: Variant, code_value: Variant, where: String) -> void:
	if not _same(doc_value, code_value):
		_fail("%s: 文書は %s、コードは %s" % [where, _show(doc_value), _show(code_value)], "")


func _show(value: Variant) -> String:
	if value == null:
		return "（数が無い）"
	if typeof(value) == TYPE_FLOAT and is_equal_approx(value, roundf(value)):
		return str(int(value))
	if typeof(value) == TYPE_ARRAY:
		var parts: Array[String] = []
		for item: Variant in value:
			parts.append(_show(item))
		return "[%s]" % ", ".join(parts)
	return var_to_str(value)


## 文書が挙げる rules/ のスクリプト（`rules/xxx.gd`）。
func _scripts_named_in(path: String) -> Array[String]:
	var found: Array[String] = []
	var regex := RegEx.create_from_string("`(rules/[A-Za-z0-9_/]+\\.gd)`")
	for match: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
		var script := "res://" + match.get_string(1)
		if not found.has(script):
			found.append(script)
	return found


## 定数 `Class.NAME`（class_name が空なら、文書の挙げるスクリプトから NAME を探す）の値。
## {"value": 値} か、見つからなければ {"error": 理由}。
func _resolve(class_name_part: String, constant: String, scripts: Array[String]) -> Dictionary:
	var candidates: Array[String] = []
	if class_name_part != "":
		for entry: Dictionary in ProjectSettings.get_global_class_list():
			if entry["class"] == class_name_part:
				candidates.append(entry["path"])
		if candidates.is_empty():
			return {"error": "クラス %s がコードに無い" % class_name_part}
	else:
		candidates = scripts
	var values := _constant_values(candidates, constant)
	if values.is_empty() and class_name_part == "":
		# 文書がスクリプトを挙げていない定数（CPU の調整値など）は、rules/ の下の全部から探す。
		candidates = _rule_scripts("res://rules")
		values = _constant_values(candidates, constant)
	if values.is_empty():
		var label := "%s.%s" % [class_name_part, constant] if class_name_part != "" else constant
		return {"error": "定数 %s がコードに無い" % label}
	for value: Variant in values:
		if not _same(value, values[0]):
			return {"error": "定数 %s が 2 つ以上のスクリプトにあって値が違う。`クラス名.%s` と書く" % [constant, constant]}
	return {"value": values[0]}


func _constant_values(scripts: Array[String], constant: String) -> Array:
	var values: Array = []
	for script_path: String in scripts:
		# 継いだスクリプトの定数もたどる（get_script_constant_map は、そのスクリプトが書いた定数だけを返す。
		# CpuPlayer の調整値は、継ぐ元の rules/cpu/cpu_player_base.gd にある）。
		var script := load(script_path) as Script
		while script != null:
			var constants := script.get_script_constant_map()
			if constants.has(constant):
				values.append(constants[constant])
				break
			script = script.get_base_script()
	return values


func _rule_scripts(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	for sub: String in dir.get_directories():
		found.append_array(_rule_scripts(dir_path.path_join(sub)))
	return found
