extends RefCounted
## 駒にいま乗っている効果の並び（docs/battle-view.md の「兵に乗っている効果」）。対戦中の兵の情報の札と、兵の詳細の窓が、
## 「名前　数」の短い札で並べる。ルールは持たない（rules/ の問い合わせを読むだけ。計算を二重に持たない）。ノードに依存しない。
##
## 出どころ: 状態（バリア・照準・反動・突撃・奮起・絡み）、軍略（集中砲火・仇討ち・誓いの印、隊列・補給線・単騎・誓いの相手）、
## 縫い目の様子（天裂の名残り・天裂の光）、魔物（胞子）、地形と環境オブジェクトと盤の上の効果（森・回復の泉・砲台・拠点・煙幕・聖域）、聖遺物。
## 進化先と持ち物が与えた特性も、最後に名前だけの札で並べる。持ち物の能力値の増減は、持ち物の枠と能力値の行の矢印に出ているので、ここには入れない。

const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")


## 効果 1 つ。
class Effect:
	extends RefCounted
	## 名前（「集中砲火」「森」）と、数のある所（「被ダメージ +2」）。
	var name := ""
	var value := ""
	## 兵にとって良いものか（色を分ける）。
	var good := true
	## 状態なら、その種類と残りのターン数（状態でなければ -1）。
	var status := -1
	var turns := -1
	## 能力値の行の数に入っているか（入っていなければ、札だけが知らせる）。
	var in_stats := false
	## 駒の特性（進化先と持ち物が与えたもの。良い・悪いでなく、特性の色で出す）。
	var is_trait := false

	func _init(name_: String, value_: String, good_: bool, in_stats_ := false) -> void:
		name = name_
		value = value_
		good = good_
		in_stats = in_stats_

	## 1 行の文（検査用）。
	func line() -> String:
		var words := name if value == "" else Text.t("battle.effect.line", {"name": name, "value": value})
		return words if turns < 0 else Text.t("battle.effect.line_turns", {"line": words, "turns": turns})


## battle の駒 unit に、いま乗っている効果。並びは、状態 → 軍略 → 縫い目 → 魔物 → 地形 → 聖遺物 → 駒の特性。
static func of(battle: Battle, unit: Unit) -> Array[Effect]:
	var found: Array[Effect] = []
	if battle == null or unit == null:
		return found
	_statuses(unit, found)
	_traits(battle, unit, found)
	_signs(battle, unit, found)
	var spores := Monsters.spore_penalty(battle, unit)
	if spores > 0:
		found.append(Effect.new(Text.t("battle.effect.spores"), _stat(Unit.Stat.POWER, -spores), false))
	_ground(battle, unit, found)
	_relics(battle, unit, found)
	for which: Evolution.Trait in Evolution.Trait.values():  # 進化先と持ち物の、どちらが与えた特性も（重ねても 1 つ）
		if unit.has_trait(which):
			var held := Effect.new(Names.trait_short(which), "", true)
			held.is_trait = true
			found.append(held)
	return found


static func _statuses(unit: Unit, found: Array[Effect]) -> void:
	for type: Status.Type in Statuses.types_of(unit):
		var value := ""
		var good := true
		var bonus := Status.bonus(type)
		if Status.blocks_damage(type):
			value = Text.t("battle.effect.blocks")
		elif Status.roots(type):
			value = Text.t("battle.effect.stat", {"stat": Names.stat(Unit.Stat.MOVE_RANGE), "amount": 0})
			good = false
		else:
			var parts: Array[String] = []
			for which: Unit.Stat in bonus:
				parts.append(_stat(which, bonus[which]))
				good = good and int(bonus[which]) > 0
			value = Text.t("battle.effect.joiner").join(PackedStringArray(parts))
		var effect := Effect.new(Names.status(type), value, good, not bonus.is_empty())
		effect.status = type
		effect.turns = unit.statuses[type]
		found.append(effect)


static func _traits(battle: Battle, unit: Unit, found: Array[Effect]) -> void:
	# 相手の軍略の印（狙うと増える）。
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		if side == unit.side:
			continue
		if Traits.focus_marked(battle, unit, side):
			found.append(Effect.new(Names.troop_trait(Traits.Id.FOCUS), _taken(Traits.FOCUS_BONUS), false))
		if Traits.vengeance_marked(battle, unit, side):
			found.append(Effect.new(Names.troop_trait(Traits.Id.VENGEANCE), _taken(Traits.VENGEANCE_BONUS), false))
		if Traits.of_side(battle, side) == Traits.Id.OATH:
			for other in battle.units:
				if other.side == side and Traits.oath_marked(battle, other, unit):
					found.append(Effect.new(Names.troop_trait(Traits.Id.OATH), _taken(Traits.OATH_BONUS), false))
					break
	if unit.side == Unit.Side.NEUTRAL:
		return
	# 自分の軍略。
	if Traits.guard_of(battle, unit) > 0:
		found.append(Effect.new(Names.troop_trait(Traits.Id.RANKS), _taken(-Traits.RANKS_GUARD), true))
	if Traits.supplier_at(battle, unit, unit.cell) != null:
		found.append(Effect.new(Names.troop_trait(Traits.Id.SUPPLY), _heal(Traits.SUPPLY_HEAL), true))
	if unit.kind != UnitKind.Id.KING and Traits.alone_at(battle, unit, unit.cell):
		found.append(Effect.new(Names.troop_trait(Traits.Id.LONE), _damage(Traits.LONE_BONUS), true))
	var partner := Traits.partner_of(battle, unit)
	if partner != null:
		found.append(Effect.new(Names.troop_trait(Traits.Id.OATH), Text.t("battle.effect.partner", {"unit": Names.unit(partner)}), true))


static func _signs(battle: Battle, unit: Unit, found: Array[Effect]) -> void:
	if unit.hazed:
		found.append(Effect.new(Names.sign_name(Seam.Sign.HAZE), _stat(Unit.Stat.ATTACK_RANGE, -Seam.HAZE_CUT), false, true))
	for which: Unit.Stat in unit.sign_bonus:
		if battle.signs.has(Seam.Sign.GLEAM) and which == Unit.Stat.ATTACK_RANGE:
			found.append(Effect.new(Names.sign_name(Seam.Sign.GLEAM), _stat(which, unit.sign_bonus[which]), true, true))


static func _ground(battle: Battle, unit: Unit, found: Array[Effect]) -> void:
	var board := battle.board
	if board.terrain_at(unit.cell) == Terrain.Type.FOREST:
		var rate := Seam.forest_rate_percent(battle)
		var name := Text.t("battle.cell.forest")
		if rate != Combat.FOREST_DAMAGE_RATE_PERCENT:
			name = Names.sign_name(Seam.Sign.THICKET)
		found.append(Effect.new(name, Text.t("battle.effect.taken_rate", {"amount": "%d" % (rate - 100)}), true))
	match board.object_at(unit.cell):
		MapObject.Type.SPRING:
			if unit.side != Unit.Side.NEUTRAL:
				found.append(Effect.new(Text.t("battle.cell.spring"), _heal(MapObject.SPRING_HEAL), true))
		MapObject.Type.STRONGHOLD:
			if Stronghold.counts(unit):
				found.append(Effect.new(Text.t("battle.cell.stronghold"), Text.t("battle.effect.hold"), true))
	if unit.site_range > 0:
		found.append(Effect.new(Text.t("battle.cell.battery"), _stat(Unit.Stat.ATTACK_RANGE, unit.site_range), true, true))
	if FieldEffects.smoke_of(battle, unit) != null:
		found.append(Effect.new(Names.field_effect(FieldEffect.Type.SMOKE), Text.t("battle.effect.smoke"), true))
	if FieldEffects.sanctuary_of(battle, unit) != null:
		found.append(Effect.new(Names.field_effect(FieldEffect.Type.SANCTUARY), _heal(FieldEffects.SANCTUARY_HEAL), true))


static func _relics(battle: Battle, unit: Unit, found: Array[Effect]) -> void:
	if unit.side == Unit.Side.NEUTRAL or int(unit.side) >= battle.relics.size():
		return
	for relic: Relics.Id in battle.relics[unit.side]:
		found.append(Effect.new(Names.relic_short(relic), Names.relic_effect(relic), true, true))


## 「攻撃 +4」「射程 -1」。
static func _stat(which: Unit.Stat, amount: int) -> String:
	return Text.t("battle.effect.stat", {"stat": Names.stat(which), "amount": _signed(amount)})


## 「被ダメージ +2」（受けるダメージの増減）。
static func _taken(amount: int) -> String:
	return Text.t("battle.effect.taken", {"amount": _signed(amount)})


## 「ダメージ +1」（与えるダメージの増減）。
static func _damage(amount: int) -> String:
	return Text.t("battle.effect.damage", {"amount": _signed(amount)})


## 「HP +4」（番の始めの回復）。
static func _heal(amount: int) -> String:
	return Text.t("battle.effect.heal", {"amount": amount})


static func _signed(amount: int) -> String:
	return ("+%d" % amount) if amount > 0 else ("%d" % amount)
