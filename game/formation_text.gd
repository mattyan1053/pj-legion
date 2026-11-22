## 組み方（docs/formation.md）の画面の文。対戦の駒の情報の枠・ステータスの窓と、部隊編成の画面が使う。ノードに依存しない。

const Names := preload("res://game/names.gd")
const Text := preload("res://game/text.gd")


## 駒 unit の組み方の行（駒の情報の枠とステータスの窓。docs/formation.md）。組み方が切か、分隊でも誓いでもなければ空。
static func unit_lines(battle: Battle, unit: Unit) -> Array[String]:
	var lines: Array[String] = []
	if battle == null or unit == null or not battle.formation:
		return lines
	var squad := Formation.squad_of(battle, unit)
	if not squad.is_empty():
		var key := "battle.hud.squad_guarded" if Formation.guarded(battle, unit) else "battle.hud.squad"
		lines.append(Text.t(key, {"kind": Names.kind(unit.kind), "count": squad.size(), "guard": Formation.SQUAD_GUARD, "focus": Formation.SQUAD_FOCUS}))
	var partner := Formation.partner_of(battle, unit)
	if partner != null:
		var key := "battle.hud.oath_near" if Formation.oath_near(battle, unit) else "battle.hud.oath"
		lines.append(Text.t(key, {"unit": Names.unit(partner), "range": Formation.OATH_RANGE, "vengeance": Formation.OATH_VENGEANCE}))
		var foe := Formation.foe_of_partner(battle, unit)
		if foe != null:
			lines.append(Text.t("battle.hud.oath_foe", {"unit": Names.unit(foe), "vengeance": Formation.OATH_VENGEANCE}))
	return lines




# ---- 部隊編成 ----


## 部隊編成の組み方の欄の文（対戦用の部隊）。1 行目は組んだもの（分隊の兵種と体数 / 誓いの組）、続けて軍の組み方の効果。
## binding が 0 以上なら、その駒の結ぶ相手を選んでいる。
static func deck_text(deck: Deck, binding := -1) -> String:
	var lines: Array[String] = [Text.t("deck.formation.title")]
	if Formation.binds_oaths(deck.army):
		var pairs: Array[String] = []
		for pair in deck.oath_pairs():
			pairs.append(Text.t("deck.formation.pair", {"a": Names.kind(deck.entries[pair.x].kind), "b": Names.kind(deck.entries[pair.y].kind)}))
		if binding >= 0 and binding < deck.entries.size():
			lines.append(Text.t("deck.formation.binding", {"unit": Names.kind(deck.entries[binding].kind)}))
		elif pairs.is_empty():
			lines.append(Text.t("deck.formation.no_oath", {"max": Formation.MAX_OATHS}))
		else:
			lines.append(Text.t("deck.formation.oaths", {"pairs": Text.join_comma(pairs), "count": pairs.size(), "max": Formation.MAX_OATHS}))
	elif deck.army != UnitKind.Army.NONE:
		var squads: Array[String] = []
		for kind in Formation.squad_kinds(deck):
			var size := deck.entries.filter(func(entry: DeckEntry) -> bool: return entry.kind == kind).size()
			squads.append(Text.t("deck.formation.squad", {"kind": Names.kind(kind), "count": size}))
		lines.append(Text.t("deck.formation.no_squad", {"size": Formation.SQUAD_SIZE}) if squads.is_empty() else Text.t("deck.formation.squads", {"squads": Text.join_comma(squads)}))
	for effect in Formation.effects_of(deck.army):
		lines.append(Text.t("deck.formation.effect", {"effect": Names.formation_effect(effect), "summary": Names.formation_summary(effect)}))
	return "\n".join(lines)


## 部隊の行の「誓い」のボタンの文（結んでいれば何組目か）。
static func oath_tag(deck: Deck, entry: DeckEntry) -> String:
	for i in deck.oaths.size():
		if deck.oaths[i].has(entry):
			return Text.t("deck.formation.oath_tag_bound", {"number": i + 1})
	return Text.t("deck.formation.oath_tag")


## 「誓い」のボタンに乗ると出る文（結んだ相手）。
static func oath_tooltip(deck: Deck, entry: DeckEntry) -> String:
	var partner := deck.partner_of(entry)
	return "" if partner == null else Text.t("deck.formation.partner", {"unit": Names.kind(partner.kind)})
