## 部隊の特徴（docs/troop-traits.md）の画面の文。部隊編成の画面と、対戦の上の帯が使う。ノードに依存しない。

const Names := preload("res://game/names.gd")
const Text := preload("res://game/text.gd")


## 部隊編成の、誓いの欄の文（特徴が誓いの部隊だけ）。結んだ組か、結ぶ相手を選んでいる駒。
## binding が 0 以上なら、その駒の結ぶ相手を選んでいる。
static func oath_text(deck: Deck, binding := -1) -> String:
	if binding >= 0 and binding < deck.entries.size():
		return Text.t("deck.trait.binding", {"unit": Names.kind(deck.entries[binding].kind)})
	var pairs: Array[String] = []
	for pair in deck.oath_pairs():
		pairs.append(Text.t("deck.trait.pair", {"a": Names.kind(deck.entries[pair.x].kind), "b": Names.kind(deck.entries[pair.y].kind)}))
	if pairs.is_empty():
		return Text.t("deck.trait.no_oath", {"max": Traits.MAX_OATHS})
	return Text.t("deck.trait.oaths", {"pairs": Text.join_comma(pairs), "count": pairs.size(), "max": Traits.MAX_OATHS})


## 部隊の行の「誓い」のボタンの文（結んでいれば何組目か）。
static func oath_tag(deck: Deck, entry: DeckEntry) -> String:
	for i in deck.oaths.size():
		if deck.oaths[i].has(entry):
			return Text.t("deck.trait.oath_tag_bound", {"number": i + 1})
	return Text.t("deck.trait.oath_tag")


## 「誓い」のボタンに乗ると出る文（結んだ相手）。
static func oath_tooltip(deck: Deck, entry: DeckEntry) -> String:
	var partner := deck.partner_of(entry)
	return "" if partner == null else Text.t("deck.trait.partner", {"unit": Names.kind(partner.kind)})


## 対戦の上の帯の、陣営 side の特徴の札の文（名前だけ）。特徴が無ければ空。
static func band_text(battle: Battle, side: Unit.Side) -> String:
	var id := Traits.of_side(battle, side) if battle != null else Traits.NONE
	return Names.troop_trait(id)


## 札に乗ると出る文（名前と 1 行の文）。
static func band_tooltip(battle: Battle, side: Unit.Side) -> String:
	var id := Traits.of_side(battle, side) if battle != null else Traits.NONE
	return "" if id == Traits.NONE else Text.t("battle.hud.troop_trait", {"name": Names.troop_trait(id), "text": Names.troop_trait_text(id)})
