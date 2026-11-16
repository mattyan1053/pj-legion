extends RefCounted
## 編成の画面と対戦の設定に出す文（出せない理由、駒・装備の中身、編成の短い説明）。ノードに依存しない。
## 理由の文言は画面の側が持つ（docs/deck-building.md）。

const Names := preload("res://game/names.gd")

## 役割ごとの、ひとことの説明。
const ROLE_NOTES := {
	UnitKind.Role.VANGUARD: "前に立って受け止める。周り 8 マスに支配領域を作り、敵はそこで止まる",
	UnitKind.Role.REARGUARD: "離れたところから撃つ",
	UnitKind.Role.RAIDER: "よく動き、弱った駒や本陣を狙う",
	UnitKind.Role.HEALER: "味方の HP を回復する（攻撃のかわりに回復）",
}


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
			return "駒が 1 体もいない"
		Deck.Problem.TOO_MANY_UNITS:
			return "駒が多すぎる（%d 体まで）" % deck.rules.max_units
		Deck.Problem.OVER_BUDGET:
			return "予算を %d 超えている" % (deck.total_cost() - deck.budget())
		Deck.Problem.TOO_MUCH_EQUIPMENT:
			return "装備を持たせすぎた駒がいる（1 体 %d 個まで）" % Equipment.MAX_PER_UNIT
		Deck.Problem.NOT_IN_ROSTER:
			return "この軍では雇えない駒がいる"
		Deck.Problem.ITEM_NOT_ALLOWED:
			return "まだ持たせられない装備を持った駒がいる"
	return "出せない"


## 能力値の 1 行（「HP 44　攻撃 6　移動 3　射程 1」）。回復役は「攻撃」のかわりに「回復」。
## bonus（Unit.Stat -> 足す量）を渡すと、足したあとの値を出す。
static func stats_line(kind: UnitKind.Id, bonus := {}) -> String:
	var power_name := "回復" if UnitKind.role(kind) == UnitKind.Role.HEALER else "攻撃"
	return "HP %d　%s %d　移動 %d　射程 %d" % [
		UnitKind.max_hp(kind) + int(bonus.get(Unit.Stat.MAX_HP, 0)),
		power_name, UnitKind.power(kind) + int(bonus.get(Unit.Stat.POWER, 0)),
		UnitKind.move_range(kind) + int(bonus.get(Unit.Stat.MOVE_RANGE, 0)),
		UnitKind.attack_range(kind) + int(bonus.get(Unit.Stat.ATTACK_RANGE, 0)),
	]


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
				name = "回復"
			parts.append("%s %+d" % [name, amount])
	return "、".join(parts)


## 装備 1 個の効果（「移動力 +2」）。
static func equipment_effect(item: Equipment.Id) -> String:
	var bonus := {}
	for stat: Unit.Stat in Unit.Stat.values():
		if Equipment.bonus(item, stat) != 0:
			bonus[stat] = Equipment.bonus(item, stat)
	return bonus_text(bonus)


## スキルの 1 行目（名前）と説明。持たなければ空。
static func skill_text(kind: UnitKind.Id) -> String:
	var skill := Skills.of_kind(kind)
	if skill == null:
		return ""
	return "%s（クールダウン %d ターン）\n%s" % [Names.skill(skill), skill.cooldown(), Names.skill_summary(skill)]


## 進化先の文（1 つ 1 行。名前と、能力値の増減と、特性）。
static func evolution_lines(kind: UnitKind.Id) -> Array[String]:
	var lines: Array[String] = []
	for evolution in Evolution.options_for(kind):
		var parts: Array[String] = []
		var bonus := bonus_text(Evolution.bonuses(evolution), kind)
		if bonus != "":
			parts.append(bonus)
		for which in Evolution.traits(evolution):
			parts.append(Names.trait_text(which))
		lines.append("%s: %s" % [Names.evolution(evolution), "、".join(parts)])
	return lines


## 編成の 1 行の説明（対戦の設定に出す。「将、シールドトルーパー+アイアンシールド×2、…」。同じ装備は数をまとめる）。
static func deck_summary(deck: Deck) -> String:
	var parts: Array[String] = ["将"]
	for entry in deck.entries:
		var text := Names.kind(entry.kind)
		var counted: Array[Equipment.Id] = []
		for item in entry.equipment:
			if counted.has(item):
				continue
			counted.append(item)
			var count := entry.equipment.count(item)
			text += "+" + Names.item(item) + ("×%d" % count if count > 1 else "")
		parts.append(text)
	return "、".join(parts)


## 駒 1 体の装備の短い文（「ブーツ 2、盾 1」）。持っていなければ空。
static func equipment_short(items: Array[Equipment.Id]) -> String:
	var parts: Array[String] = []
	for item: Equipment.Id in Equipment.Id.values():
		var count := items.count(item)
		if count > 0:
			parts.append("%s ×%d" % [Names.item(item), count])
	return "、".join(parts)
