extends RefCounted
## 駒 1 体のステータス（駒の詳細の窓 unit_detail.gd が出す中身）。ノードに依存しない（テストから呼べる）。
## 文の段落ではなく、欄ごとの値で持つ: 名前・役割・軍・コスト、レベルと経験値、HP、能力値（素の値と増減）、スキル、必殺技、持ち物、進化先、状態。
##
## - 編成の駒（of_kind）: 駒の種類・持ち物・始めのレベルから作る。HP は満タン、経験値は 0。
## - 対戦中の駒（of_unit）: いまの HP・レベル・経験値・状態・スキルの残りを写す。
##
## 能力値は「素の値」（種類の値 + レベルアップ + 進化）と「増減」（持ち物。対戦中は聖遺物・状態も）に分ける。
## 画面は、いまの値（素の値 + 増減）を大きく出し、増減を色と矢印で添える。

const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")

## 能力値の並び（HP、攻撃か回復、移動、射程）。
const STATS: Array[Unit.Stat] = [Unit.Stat.MAX_HP, Unit.Stat.POWER, Unit.Stat.MOVE_RANGE, Unit.Stat.ATTACK_RANGE]
## 目盛りの端の値（能力値ごと。これを超える駒は、その駒の値が端になる）。HP と攻撃は棒、移動と射程は粒。
const SCALES := {Unit.Stat.MAX_HP: 120, Unit.Stat.POWER: 24, Unit.Stat.MOVE_RANGE: 10, Unit.Stat.ATTACK_RANGE: 8}

## 能力値 1 つ。
class StatLine:
	extends RefCounted
	var stat: Unit.Stat
	var name := ""
	## いまの値（素の値 + 増減）と、素の値。
	var value := 0
	var plain := 0

	## 持ち物など（素の値に足されているもの）での増減。
	func delta() -> int:
		return value - plain


var kind := UnitKind.Id.KING
var side := 0
## 将の別の姿（unit_looks.gd の KING_LOOKS）。
var look := &""
## 部隊の軍（必殺技と、軍の色・紋。魔物と中立は NONE）。
var army := UnitKind.Army.NONE
## ほかの軍から雇った駒か（ストーリーで解放した駒。駒の種類の軍が、部隊の軍と違う）。
var borrowed := false
var name := ""
var level := 1
var experience := 0
## 育つ駒か（軍に属する駒だけ。将・魔物・中立は育たない）。
var grows := false
var hp := 0
var stats: Array[StatLine] = []
var skill: Skill
## スキルのいまの状態（対戦中だけ。「使用可」「あと 2 ターン」）。空なら、クールダウンの長さを出す。
var skill_state := ""
var ult: Ult
## 持ち物（[持ち物, 数] を持たせた順に。同じものはまとめる）と、持てる数の上限（持てない駒は 0）。
var items: Array = []
var item_slots := 0
## 選べる進化先（進化した駒は、その進化先だけ）と、進化したか。
var evolutions: Array[Evolution.Id] = []
var evolved := Evolution.Id.NONE
## 付いている状態（[種類, 残りのターン数]。対戦中だけ）。
var statuses: Array = []
## 回復役の攻撃の強さ（回復役でなければ 0）。情報の札の名前の右に「攻撃 4」と出す（info_card.gd）。
var strike := 0


## 編成の駒。equipment は持ち物、deck_army は部隊の軍（-1 なら駒の種類の軍）、start_level は始めのレベル。
static func of_kind(of: UnitKind.Id, equipment: Array[Equipment.Id] = [], side_ := 0, deck_army := -1, start_level := 1, look_ := &"") -> RefCounted:
	var sheet := new()
	sheet._identify(of, side_, deck_army, look_)
	var role := UnitKind.role(of)
	sheet.grows = Growth.GAINS.has(role)
	sheet.level = Growth.start_level(start_level) if sheet.grows else 1
	var grown: Dictionary = {}
	if sheet.grows:
		var gains: Dictionary = Growth.GAINS[role]
		for stat: Unit.Stat in gains:
			grown[stat] = int(gains[stat]) * (sheet.level - 1)
	for stat in STATS:
		var plain := _kind_value(of, stat) + int(grown.get(stat, 0))
		sheet._add_stat(stat, plain, maxi(plain + Equipment.total_bonus(equipment, stat), 1 if stat == Unit.Stat.MAX_HP else 0))
	sheet.hp = sheet.stats[0].value
	sheet.strike = UnitKind.healer_strike(of)
	sheet._hold(equipment)
	sheet.evolutions = Evolution.options_for(of)
	return sheet


## 対戦中の駒。side_army は陣営の軍（Battle.armies）、skill_state_ はスキルのいまの状態の文（battle_hud.gd の skill_state_text）。
static func of_unit(unit: Unit, side_army := UnitKind.Army.NONE, skill_state_ := "", look_ := &"") -> RefCounted:
	var sheet := new()
	sheet._identify(unit.kind, unit.side, side_army if side_army != UnitKind.Army.NONE else -1, look_)
	sheet.name = Names.unit(unit)
	sheet.grows = Growth.can_grow(unit)
	sheet.level = unit.level
	sheet.experience = unit.experience
	for stat in STATS:
		var plain := _kind_value(unit.kind, stat) + int(unit.growth_bonus.get(stat, 0)) + Evolution.bonus(unit.evolution, stat)
		sheet._add_stat(stat, plain, unit.stat(stat))
	sheet.hp = unit.hp
	sheet.strike = Combat.attack_power(unit) if UnitKind.role(unit.kind) == UnitKind.Role.HEALER else 0
	sheet._hold(unit.equipment)
	sheet.skill_state = skill_state_ if sheet.skill != null else ""
	sheet.evolved = unit.evolution
	if unit.evolution != Evolution.Id.NONE:
		sheet.evolutions = [unit.evolution]
	else:
		sheet.evolutions = Evolution.options_for(unit.kind)
	for type in Statuses.types_of(unit):
		sheet.statuses.append([type, unit.statuses[type]])
	return sheet


func _identify(of: UnitKind.Id, side_: int, deck_army: int, look_: StringName) -> void:
	kind = of
	side = side_
	look = look_
	name = Names.kind(of)
	var own := UnitKind.army(of)
	if UnitKind.is_neutral(of) or UnitKind.is_monster(of):
		army = UnitKind.Army.NONE
	else:
		army = (deck_army as UnitKind.Army) if deck_army > UnitKind.Army.NONE else own
	borrowed = own != UnitKind.Army.NONE and army != own
	skill = Skills.of_kind(of)
	ult = Ults.of_army(army)


func _add_stat(stat: Unit.Stat, plain: int, value: int) -> void:
	var line := StatLine.new()
	line.stat = stat
	line.plain = plain
	line.value = value
	line.name = Names.stat(stat)
	if stat == Unit.Stat.MAX_HP:
		line.name = Text.t("deck.sheet.hp")
	elif stat == Unit.Stat.POWER and UnitKind.role(kind) == UnitKind.Role.HEALER:
		line.name = Text.t("battle.log.stat_heal")
	stats.append(line)


func _hold(equipment: Array[Equipment.Id]) -> void:
	item_slots = Equipment.MAX_PER_UNIT if Equipment.can_equip(kind) else 0
	for item in equipment:
		var found := false
		for held: Array in items:
			if held[0] == item:
				held[1] += 1
				found = true
		if not found:
			items.append([item, 1])


static func _kind_value(of: UnitKind.Id, stat: Unit.Stat) -> int:
	match stat:
		Unit.Stat.MAX_HP:
			return UnitKind.max_hp(of)
		Unit.Stat.POWER:
			return UnitKind.power(of)
		Unit.Stat.MOVE_RANGE:
			return UnitKind.move_range(of)
	return UnitKind.attack_range(of)


func stat_line(stat: Unit.Stat) -> StatLine:
	for line in stats:
		if line.stat == stat:
			return line
	return null


func max_hp() -> int:
	return stats[0].value


## 目盛りの端の値（その能力値の、棒や粒の全体が表す値）。
func scale_of(stat: Unit.Stat) -> int:
	var line := stat_line(stat)
	return maxi(int(SCALES[stat]), maxi(line.value, line.plain))


## 駒の持つ特性（進化先と持ち物のどちらが与えたものも。重ねても 1 つ）。
func traits() -> Array[Evolution.Trait]:
	var found: Array[Evolution.Trait] = []
	for which: Evolution.Trait in Evolution.Trait.values():
		var held := Evolution.has_trait(evolved, which)
		for item: Array in items:
			held = held or Equipment.traits(item[0]).has(which)
		if held:
			found.append(which)
	return found


## 名前の下の札の文（役割、軍。将は「本陣に配置」、魔物は「魔物」）。
func tags() -> Array[String]:
	var found: Array[String] = []
	var role := UnitKind.role(kind)
	if role != UnitKind.Role.NONE:
		found.append(Names.role(role))
	if kind == UnitKind.Id.KING:
		found.append(Text.t("deck.card.king"))
	if UnitKind.is_monster(kind):
		found.append(Text.t("battle.hud.monster"))
	elif army != UnitKind.Army.NONE:
		found.append(Names.army(army))
	return found


## コスト（雇う駒だけ。将・魔物・中立は 0 で、画面は出さない）。
func cost() -> int:
	return UnitKind.cost(kind) if UnitKind.army(kind) != UnitKind.Army.NONE else 0


## 窓に出している文の全部（検査用。欄の順に 1 行ずつ）。
func text() -> String:
	var lines: Array[String] = [name, Text.join_dot(tags())]
	if borrowed:
		lines.append(Text.t("deck.detail.borrowed", {"origin": Names.army(UnitKind.army(kind)), "army": Names.army(army)}))
	for line in stats:
		lines.append("%s %d" % [line.name, line.value])
	if skill != null:
		lines.append(Text.t("deck.sheet.skill"))
		lines.append(Names.skill(skill))
		lines.append(Names.skill_summary(skill))
	if ult != null:
		lines.append(Names.ult(ult))
		lines.append(Names.ult_summary(ult))
	for item: Array in items:
		lines.append(Names.item(item[0]))
	for evolution in evolutions:
		lines.append(Names.evolution(evolution))
	return "\n".join(lines)
