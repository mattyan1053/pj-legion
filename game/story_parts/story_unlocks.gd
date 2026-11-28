extends "res://game/story_parts/story_record.gd"
## ストーリー（game/story.gd）の、解放（docs/story.md の「解放」）と既定の編成: 物語の最初の値に、クリアした話の解放を足したもの。
## 記録には書かず、その場で求める。ノードに依存しない。継ぐ順は story_catalog.gd の頭。

## 既定の編成で、役割ごとに 1 つ持たせる装備の候補（前から順に、持たせられて、コストが収まる最初の 1 つ。無い役割は持たせない）。
## ストーリー専用の持ち物（ジェットパック、古竜の鱗）を解放したら、盾・ブーツのかわりに持たせる。
## ほかの新しい持ち物は持たせない（どの駒に何を持たせるかは、人が選ぶ。既定の編成は素直な形のまま）。
const DEFAULT_ITEMS := {
	UnitKind.Role.VANGUARD: [Equipment.Id.DRAGON_SCALE, Equipment.Id.IRON_SHIELD],
	UnitKind.Role.RAIDER: [Equipment.Id.JET_PACK, Equipment.Id.SPEED_BOOTS],
}


## 物語の中で、いま使えるもの: 雇える駒の種類、持たせられる装備、部隊のコストの上限。
## 物語の最初の値（物語のファイルの [start] と budget）に、クリアした話の解放（話のファイルの [unlock]）を足したもの。記録には書かず、その場で求める。
class Unlocked:
	extends RefCounted
	var campaign: Campaign
	var kinds: Array[UnitKind.Id] = []
	var items: Array[Equipment.Id] = []
	var budget := 0
	## 選べる軍略（Traits.Id。教わった軍略）。
	var traits: Array[int] = []

	func _init(of_campaign: Campaign) -> void:
		campaign = of_campaign
		kinds.assign(of_campaign.starting_kinds)
		items.assign(of_campaign.starting_items)
		traits.assign(of_campaign.starting_traits)
		budget = of_campaign.starting_budget

	## 話 episode のクリアで増えるものを足す。
	func add(episode: Episode) -> void:
		for kind: UnitKind.Id in episode.unlock_kinds:
			if not kinds.has(kind):
				kinds.append(kind)
		for item: Equipment.Id in episode.unlock_items:
			if not items.has(item):
				items.append(item)
		for id: int in episode.unlock_traits:
			if not traits.has(id):
				traits.append(id)
		budget += episode.budget_up

	## 話 episode のクリアで、これより新しく増えるものの知らせの行（会話の、知らせの行。増えるものが無ければ空）。
	## 駒・持ち物・軍略の知らせは、文の左に、そのアイコンを出す（行の unit_kind・item・troop_trait）。
	func news_of(episode: Episode) -> Array[TalkScene.Line]:
		var lines: Array[TalkScene.Line] = []
		for kind: UnitKind.Id in episode.unlock_kinds:
			if not kinds.has(kind):
				lines.append(_notice(Text.t("story.news.unit", {"unit": Names.kind(kind)})))
				lines.back().unit_kind = kind
		for item: Equipment.Id in episode.unlock_items:
			if not items.has(item):
				lines.append(_notice(Text.t("story.news.item", {"item": Names.item(item), "effect": DeckText.equipment_effect(item)})))
				lines.back().item = item
		for id: int in episode.unlock_traits:
			if not traits.has(id):
				lines.append(_notice(Text.t("story.news.trait", {"name": Names.troop_trait(id), "text": Names.troop_trait_text(id)})))
				lines.back().troop_trait = id
		var more := episode.budget_up
		if more > 0:
			lines.append(_notice(Text.t("story.news.budget", {"budget": budget + more})))
		return lines

	static func _notice(said: String) -> TalkScene.Line:
		return TalkScene.Line.new(TalkScene.NOTICE_SIDE, Text.t("story.news.speaker"), said)


## いまの物語で、いま使えるもの（クリアした話から求める）。
func unlocked() -> Unlocked:
	return _unlocked_in(campaign)


## いま雇える駒の種類（いまの物語で）。
func unlocked_kinds() -> Array[UnitKind.Id]:
	return unlocked().kinds


## 確かめ用に開いている間は、物語の全部の話の解放を足したもの（real なら、開いていても記録どおり）。
func _unlocked_in(of_campaign: Campaign, real := false) -> Unlocked:
	var result := Unlocked.new(of_campaign)
	var cleared := _cleared_in(of_campaign)
	for episode: Episode in of_campaign.episodes:
		if cleared.has(String(episode.id)) or (open_all and not real):
			result.add(episode)
	return result


## いまの物語の、いまの進み具合の、編成の決まり。
func deck_rules() -> DeckRules:
	return rules_of(unlocked())


## 決まりの名前 rules_id の物語の、いまの進み具合の編成の決まり（どの物語の名前でもなければ null）。
## 取っておいた部隊を読むときに使う（app_context.gd）。
func rules_by_id(rules_id: StringName) -> DeckRules:
	for each: Campaign in campaigns():
		if each.rules_id == rules_id:
			return rules_of(_unlocked_in(each))
	return null


## 話 episode を初めて遊ぶときに使えるもの: その物語の最初の値と、並びでその話より前の話の解放。
## 話の敵の強さは、これで組んだ既定の編成で測る（tools/cpu_matches.gd の --episode）。
static func unlocked_before(episode: Episode) -> Unlocked:
	var of_campaign := campaign_of(episode)
	var result := Unlocked.new(of_campaign)
	for earlier: Episode in of_campaign.episodes:
		if earlier == episode:
			break
		result.add(earlier)
	return result


## 話 episode を初めて遊ぶときに雇える駒の種類。
static func kinds_before(episode: Episode) -> Array[UnitKind.Id]:
	return unlocked_before(episode).kinds


## 使えるもの given の、ストーリーの編成の決まり（名前は物語の rules_id）。
## 数の上限は対戦と同じ。予算は、物語と進み具合で決まる（対戦の予算を超えてもよい）。並びは役割の順（前衛・後衛・奇襲・回復）。
static func rules_of(given: Unlocked) -> DeckRules:
	var roster := given.kinds.duplicate()
	roster.sort_custom(func(a: UnitKind.Id, b: UnitKind.Id) -> bool:
		return UnitKind.role(a) < UnitKind.role(b) or (UnitKind.role(a) == UnitKind.role(b) and a < b))
	var army: UnitKind.Army = given.campaign.army
	return DeckRules.new(given.campaign.rules_id, Deck.MAX_UNITS, {army: roster}, {army: given.budget}, given.items, offered_items(given.campaign), given.traits)


## 物語 of_campaign で持たせられるようになる持ち物の全部（最初から持たせられるものと、どれかの話の解放で増えるもの）。
## 編成の画面は、このうちまだ持たせられないものを「未解放」で並べる。
static func offered_items(of_campaign: Campaign) -> Array[Equipment.Id]:
	var result: Array[Equipment.Id] = []
	result.assign(of_campaign.starting_items)
	for episode: Episode in of_campaign.episodes:
		for item: Equipment.Id in episode.unlock_items:
			if not result.has(item):
				result.append(item)
	return result


## 使えるもの given の、ストーリーの既定の編成。初めて遊ぶ人が出撃準備で見て納得できる、素直な形にする:
## 1. 雇える駒を、役割の順（前衛・後衛・奇襲・回復）に 1 体ずつ、数の上限まで繰り返して雇う（予算に収まるかぎり。まんべんなく）
## 2. 余った予算で、役割ごとの既定の持ち物（DEFAULT_ITEMS。前衛に盾、奇襲にブーツ、など）を、1 体に 1 つまで持たせる（持たせられる装備だけ）
## 並びは役割の順（同じ種類はまとめる）。並びの順に初期位置へ置かれるので、前衛が前に出る。
static func default_deck(given: Unlocked) -> Deck:
	var rules := rules_of(given)
	var deck := Deck.new(given.campaign.army, rules)
	var roster := deck.available_kinds()
	var hired: Array[UnitKind.Id] = []
	var cost := 0
	var adding := not roster.is_empty()
	while adding:
		adding = false
		for kind in roster:
			if hired.size() < rules.max_units and cost + UnitKind.cost(kind) <= deck.budget():
				hired.append(kind)
				cost += UnitKind.cost(kind)
				adding = true
	hired.sort_custom(func(a: UnitKind.Id, b: UnitKind.Id) -> bool: return roster.find(a) < roster.find(b))
	for kind in hired:
		deck.add(kind)
	equip_defaults(deck)
	CpuDeck.pick_trait(deck)  # 教わった軍略から、部隊の中身に合うもの（まだ教わっていなければ、持たない）
	return deck


## 部隊 deck の駒に、並びの順に、既定の持ち物（DEFAULT_ITEMS）を 1 体に 1 つまで持たせる（決まりで持たせられ、その駒が持てて、コストが収まるものだけ）。
## 既定の編成と、話の敵の強さを測る道具の、局ごとに変える部隊（tools/cpu_matches.gd の --squads=random）が使う。
static func equip_defaults(deck: Deck) -> void:
	for entry in deck.entries:
		for item: Equipment.Id in DEFAULT_ITEMS.get(UnitKind.role(entry.kind), []):
			if deck.rules.allows_item(item) and Equipment.can_add(entry.kind, entry.equipment, item) \
					and deck.total_cost() + Equipment.cost(item) <= deck.budget():
				entry.equip(item)
				break


## 物語 of_campaign（省けば最初の物語）の、まだ何もクリアしていないときに使えるもの。
static func starting(of_campaign: Campaign = null) -> Unlocked:
	return Unlocked.new(military() if of_campaign == null else of_campaign)


## 話 episode の対戦（人は、その話を初めて遊ぶときの既定の編成）。敵の強さを測る道具が使う。
static func first_battle(episode: Episode) -> StoryBattle:
	return StoryBattle.new(episode, default_deck(unlocked_before(episode)))
