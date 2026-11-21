extends RefCounted
## 編成の画面と対戦設定に出す文（出せない理由、駒・装備の中身、編成の短い説明）。ノードに依存しない。
## 理由の文言は画面の側が持つ（docs/deck-building.md）。

const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")



static func army_name(army: UnitKind.Army) -> String:
	return Names.army(army)


static func role_name(kind: UnitKind.Id) -> String:
	return Names.role(UnitKind.role(kind))


## 編成が対戦に出せない理由の文（Deck.problems() の順）。空なら出せる。
static func problem_texts(deck: Deck) -> Array[String]:
	var texts: Array[String] = []
	for problem in deck.problems():
		texts.append(problem_text(problem, deck))
	return texts


static func problem_text(problem: Deck.Problem, deck: Deck) -> String:
	match problem:
		Deck.Problem.NO_UNITS:
			return Text.t("deck.problem.no_units")
		Deck.Problem.TOO_MANY_UNITS:
			return Text.t("deck.problem.too_many_units", {"max": deck.rules.max_units})
		Deck.Problem.OVER_BUDGET:
			return Text.t("deck.problem.over_budget", {"over": (deck.total_cost() - deck.budget())})
		Deck.Problem.TOO_MUCH_EQUIPMENT:
			return Text.t("deck.problem.too_much_equipment", {"max": Equipment.MAX_PER_UNIT})
		Deck.Problem.NOT_IN_ROSTER:
			return Text.t("deck.problem.not_in_roster")
		Deck.Problem.ITEM_NOT_ALLOWED:
			return Text.t("deck.problem.item_not_allowed")
		Deck.Problem.ITEM_NOT_FIT:
			return Text.t("deck.problem.item_not_fit")
	return Text.t("deck.problem.other")


## 能力値の 1 行（「HP 44　攻撃 6　移動 3　射程 1」）。回復役は「攻撃」のかわりに「回復」。
## bonus（Unit.Stat -> 足す量）を渡すと、足したあとの値を出す。
static func stats_line(kind: UnitKind.Id, bonus := {}) -> String:
	var key := "deck.stats_healer" if UnitKind.role(kind) == UnitKind.Role.HEALER else "deck.stats"
	return Text.t(key, {
		"hp": UnitKind.max_hp(kind) + int(bonus.get(Unit.Stat.MAX_HP, 0)),
		"power": UnitKind.power(kind) + int(bonus.get(Unit.Stat.POWER, 0)),
		"move": UnitKind.move_range(kind) + int(bonus.get(Unit.Stat.MOVE_RANGE, 0)),
		"range": UnitKind.attack_range(kind) + int(bonus.get(Unit.Stat.ATTACK_RANGE, 0)),
	})


## 装備の並びが足す量（Unit.Stat -> 足す量）。
static func equipment_bonus(items: Array[Equipment.Id]) -> Dictionary:
	var bonus := {}
	for stat: Unit.Stat in Unit.Stat.values():
		var amount := Equipment.total_bonus(items, stat)
		if amount != 0:
			bonus[stat] = amount
	return bonus


## 能力値の増減の文（「最大 HP +18、移動 -1」）。kind が回復役なら、攻撃のかわりに「回復」と書く。
static func bonus_text(bonus: Dictionary, kind := -1) -> String:
	var parts: Array[String] = []
	for stat: Unit.Stat in [Unit.Stat.MAX_HP, Unit.Stat.POWER, Unit.Stat.MOVE_RANGE, Unit.Stat.ATTACK_RANGE]:
		var amount: int = bonus.get(stat, 0)
		if amount != 0:
			var name: String = Names.stat(stat)
			if stat == Unit.Stat.POWER and kind != -1 and UnitKind.role(kind as UnitKind.Id) == UnitKind.Role.HEALER:
				name = Text.t("battle.log.stat_heal")
			parts.append(Text.t("battle.log.stat_gain", {"stat": name, "amount": "%+d" % amount}))
	return Text.join_comma(parts)


## 装備 1 個の効果（「移動力 +2」「射程 +1（後衛専用）」）。能力値の増減、特性、持てる駒の限り。
static func equipment_effect(item: Equipment.Id) -> String:
	var bonus := {}
	for stat: Unit.Stat in Unit.Stat.values():
		if Equipment.bonus(item, stat) != 0:
			bonus[stat] = Equipment.bonus(item, stat)
	var parts: Array[String] = []
	if not bonus.is_empty():
		parts.append(bonus_text(bonus))
	for which in Equipment.traits(item):
		parts.append(Names.trait_short(which))
	var text := Text.join_comma(parts)
	var holders := holders_text(item)
	return text if holders == "" else Text.t("deck.item.with_holders", {"effect": text, "holders": holders})


## 装備の特性の説明（1 つ 1 行。部隊編成の持ち物の行のツールチップ）。特性が無ければ空。
static func equipment_traits_text(item: Equipment.Id) -> String:
	var lines: Array[String] = []
	for which in Equipment.traits(item):
		lines.append(Names.trait_text(which))
	return "\n".join(lines)


## 装備を持てる駒の限りの短い文（「後衛専用」「前衛以外」）。どの駒も持てるなら空。
static func holders_text(item: Equipment.Id) -> String:
	var roles := Equipment.roles(item)
	if roles.is_empty():
		return ""
	if roles.size() == 1:
		return Text.t("deck.item.only", {"role": Names.role(roles[0])})
	var all_roles: Array[UnitKind.Role] = [UnitKind.Role.VANGUARD, UnitKind.Role.REARGUARD, UnitKind.Role.RAIDER, UnitKind.Role.HEALER]
	var left_out := all_roles.filter(func(role: UnitKind.Role) -> bool: return not roles.has(role))
	if left_out.size() == 1:
		return Text.t("deck.item.except", {"role": Names.role(left_out[0])})
	var names: Array[String] = []
	for role in roles:
		names.append(Names.role(role))
	return Text.t("deck.item.only", {"role": Text.join_dot(names)})


## kind の駒（held を持っている）に item を持たせられない理由の短い文（役割の限り、重ねられない）。持たせられるか、数の上限だけが理由なら空。
static func item_refusal(kind: UnitKind.Id, held: Array[Equipment.Id], item: Equipment.Id) -> String:
	if not Equipment.fits(item, kind):
		return holders_text(item)
	if held.count(item) >= Equipment.stack_limit(item) and Equipment.stack_limit(item) < Equipment.MAX_PER_UNIT:
		return Text.t("deck.item.one_each", {"max": Equipment.stack_limit(item)})
	return ""


## 編成の 1 行の説明（対戦設定に出す。「将、シールドトルーパー+アイアンシールド×2、…」。同じ装備は数をまとめる）。
## levels: 部隊の並びの順の、駒の始めのレベル（戦いの定義の start_growth。ストーリーの話）。1 でない駒は、名前の後ろにレベルを出す。
## with_king が偽（将のいない群れ）なら、将を並べない。
static func deck_summary(deck: Deck, levels: Array = [], with_king := true) -> String:
	var parts: Array[String] = []
	if with_king:
		parts.append(Names.kind(UnitKind.Id.KING))
	for i in deck.entries.size():
		var entry := deck.entries[i]
		var text := Names.kind(entry.kind)
		var level: int = levels[i] if i < levels.size() else 1
		if level > 1:
			text = Text.t("deck.summary.level", {"kind": text, "level": level})
		var counted: Array[Equipment.Id] = []
		for item in entry.equipment:
			if counted.has(item):
				continue
			counted.append(item)
			var count := entry.equipment.count(item)
			text += Text.t("deck.summary.item_many", {"item": Names.item(item), "count": count}) if count > 1 else Text.t("deck.summary.item", {"item": Names.item(item)})
		parts.append(text)
	return Text.join_comma(parts)


## 駒 1 体の装備の短い文（「ブーツ 2、盾 1」）。持っていなければ空。
static func equipment_short(items: Array[Equipment.Id]) -> String:
	var parts: Array[String] = []
	for item: Equipment.Id in Equipment.Id.values():
		var count := items.count(item)
		if count > 0:
			parts.append(Text.t("battle.hud.item_count", {"item": Names.item(item), "count": count}))
	return Text.join_comma(parts)
