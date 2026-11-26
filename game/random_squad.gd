## 決まりの中でランダムに組む部隊（対戦設定の「ランダム編成」と、CPU どうしの集計の道具の --squads=random。docs/match-setup.md）。
## 種が同じなら同じ部隊。ここはノードに依存しない（テストと道具から呼べる）。


## 対戦で使う、種 battle_seed の対戦の、プレイヤー side の部隊（対戦の決まり。道具の --squads=random と同じ種の引き方）。
static func for_battle(army: UnitKind.Army, battle_seed: int, side: Unit.Side) -> Deck:
	return build(army, DeckRules.versus(), battle_seed * 2 + side)


## 決まり rules のロスターから、種 squad_seed で決まる順に、数の上限まで予算の中で雇い、
## 余った予算で、種で決まる駒に種で決まる装備を持たせる（決まりで持たせられる装備から。その駒が持てるものだけ）。並びは役割の順（前衛が前に置かれる）。
static func build(army: UnitKind.Army, rules: DeckRules, squad_seed: int) -> Deck:
	var rng := RandomNumberGenerator.new()
	rng.seed = squad_seed
	var deck := Deck.new(army, rules)
	var kinds := deck.available_kinds()
	var hired: Array[UnitKind.Id] = []
	var cost := 0
	while hired.size() < rules.max_units:
		var affordable := kinds.filter(func(kind: UnitKind.Id) -> bool: return cost + UnitKind.cost(kind) <= deck.budget())
		if affordable.is_empty():
			break
		var kind: UnitKind.Id = affordable[rng.randi_range(0, affordable.size() - 1)]
		hired.append(kind)
		cost += UnitKind.cost(kind)
	hired.sort_custom(func(a: UnitKind.Id, b: UnitKind.Id) -> bool: return UnitKind.role(a) < UnitKind.role(b))
	for kind in hired:
		deck.add(kind)
	var items := rules.items()
	while not deck.entries.is_empty() and not items.is_empty():
		var item: Equipment.Id = items[rng.randi_range(0, items.size() - 1)]
		var room := deck.entries.filter(func(entry: DeckEntry) -> bool: return entry.equipment.size() < Equipment.MAX_PER_UNIT)
		if room.is_empty() or deck.total_cost() + Equipment.cost(item) > deck.budget():
			break
		var open := room.filter(func(entry: DeckEntry) -> bool: return Equipment.can_add(entry.kind, entry.equipment, item))
		if open.is_empty():
			items.erase(item)  # この装備を持てる駒がもういない（役割の限り、重ねられない）。ほかの装備で続ける
			continue
		(open[rng.randi_range(0, open.size() - 1)] as DeckEntry).equip(item)
	CpuDeck.pick_trait(deck)  # 乱数は引かない（駒と装備は、軍略の無かったときと同じ）
	return deck
