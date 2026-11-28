class_name CpuDeck
extends RefCounted
## CPU の編成（docs/cpu-ai.md）。軍を渡すと、その軍のロスターと予算に収まる、対戦に出せる編成を作る。
## 決まり（DeckRules）を渡さなければ、対戦の決まりで組む。
##
## 乱数は使わない。同じ軍からは、いつも同じ編成になる。
## 1. 4 つの役割（前衛・後衛・奇襲・回復）を 1 体ずつ雇う
## 2. 予算と数の上限が許すかぎり、前衛、後衛、奇襲の順にもう 1 体ずつ足す
## 3. 余った予算で装備を持たせる。前衛にアイアンシールド、奇襲にスピードブーツを、1 個ずつ順に配る
## 4. 軍略を選ぶ（choose_trait。docs/troop-traits.md）。誓いなら、誓いを結ぶ（bind_oaths）




static func build(army: UnitKind.Army, rules: DeckRules = null) -> Deck:
	var deck := Deck.new(army, rules)
	var roster := deck.available_kinds()
	if roster.is_empty():
		return deck
	for kind in roster:
		_hire(deck, kind)
	for kind in roster:
		if UnitKind.role(kind) != UnitKind.Role.HEALER:
			_hire(deck, kind)
	var equipped := true
	while equipped and deck.total_cost() < deck.budget():
		equipped = false
		for entry in deck.entries:
			var wanted := _item_for(entry.kind)
			if wanted == -1:
				continue
			var item := wanted as Equipment.Id
			if deck.total_cost() + Equipment.cost(item) > deck.budget():
				continue
			if entry.equip(item):
				equipped = true
	pick_trait(deck)
	return deck


## 部隊 deck に、CPU の決め方で軍略を選んで付け（choose_trait）、誓いなら誓いを結ぶ（bind_oaths）。
## 決まりで選べない軍略なら、決まりの選び方（DeckRules.trait_for。ストーリーで、まだ教わっていない軍略）。
static func pick_trait(deck: Deck) -> void:
	deck.trait_id = choose_trait(deck)
	if deck.rules != null and deck.trait_id != Traits.NONE and not deck.rules.allows_trait(deck.trait_id):
		deck.trait_id = deck.rules.trait_for(deck)
	if deck.trait_id == Traits.Id.OATH:
		bind_oaths(deck)
	else:
		deck.oaths.clear()


## 部隊の中身に合う軍略（docs/cpu-ai.md の「軍略」）。軍でなければ Traits.NONE。
## 軍の表の cpu_traits の順に、部隊の中身に合うかを見て、最初に合ったもの（_fits）。どれも合わなければ、その軍の既定。
## 連邦: 回復役が SUPPLY_MEDICS 体以上なら補給線、同じ兵種（回復役を除く）の 2 体の組が RANKS_PAIRS 以上なら隊列、ほかは集中砲火。
## 騎士領: 守護の兵（Traits.GUARDIAN）が GUARD_PALADINS 体以上なら守護、攻撃する駒（回復役を除く）が OATH_FIGHTERS 体以上なら誓い、ほかは仇討ち。
static func choose_trait(deck: Deck) -> int:
	for each in Armies.cpu_traits(deck.army):
		if Traits.of_army(deck.army).has(each) and _fits(each, deck):
			return each
	return Traits.default_of(deck.army)


## 軍略 trait_id が、部隊 deck の中身に合うか（choose_trait）。中身を問わない軍略（集中砲火・仇討ち）は、いつも合う。
static func _fits(trait_id: int, deck: Deck) -> bool:
	var counts := {}
	var healers := 0
	for entry in deck.entries:
		counts[entry.kind] = counts.get(entry.kind, 0) + 1
		if UnitKind.role(entry.kind) == UnitKind.Role.HEALER:
			healers += 1
	match trait_id:
		Traits.Id.SUPPLY:
			return healers >= SUPPLY_MEDICS
		Traits.Id.RANKS:
			var pairs := 0
			for kind: UnitKind.Id in counts:
				if UnitKind.role(kind) != UnitKind.Role.HEALER:
					@warning_ignore("integer_division")
					pairs += counts[kind] / 2
			return pairs >= RANKS_PAIRS
		Traits.Id.GUARD:
			return counts.get(Traits.GUARDIAN, 0) >= GUARD_PALADINS
		Traits.Id.OATH:
			return deck.entries.size() - healers >= OATH_FIGHTERS
	return true


## choose_trait の数（部隊の中身の目安）。
const SUPPLY_MEDICS := 2
const RANKS_PAIRS := 2
const GUARD_PALADINS := 2
const OATH_FIGHTERS := 5


## 誓いを持てる軍（騎士領）の編成に、CPU の決め方で誓いを結ぶ（もう結んである誓いはほどく）。持てない軍なら何もしない。
## 誓いは、近くで戦う 2 人で結ぶ（同じ敵を、同じターンに 2 人で攻撃できる組）。
## 1 組目は前衛と後衛（前衛が受けた敵を、後ろから撃ち返す）。2 組目は、残りの前衛か奇襲と、残りの後衛か前衛。
## 回復役は結ばない（攻撃しないので、誓いが効かない）。
static func bind_oaths(deck: Deck) -> void:
	deck.oaths.clear()
	if not Traits.of_army(deck.army).has(Traits.Id.OATH):
		return
	var free := deck.entries.filter(func(entry: DeckEntry) -> bool: return UnitKind.role(entry.kind) != UnitKind.Role.HEALER)
	for wanted: Array in OATH_PLAN:
		var first := _take(free, wanted[0])
		var second := _take(free, wanted[1])
		if first != null and second != null:
			deck.bind(first, second)
		else:
			for entry: DeckEntry in [first, second]:
				if entry != null:
					free.append(entry)


## CPU が結ぶ誓い（役割の組。上から順に、そろう組を結ぶ）。
const OATH_PLAN: Array[Array] = [
	[UnitKind.Role.VANGUARD, UnitKind.Role.REARGUARD],
	[UnitKind.Role.VANGUARD, UnitKind.Role.RAIDER],
	[UnitKind.Role.RAIDER, UnitKind.Role.REARGUARD],
	[UnitKind.Role.REARGUARD, UnitKind.Role.REARGUARD],
	[UnitKind.Role.VANGUARD, UnitKind.Role.VANGUARD],
]


## free から、その役割の最初の駒を取り出す。無ければ null。
static func _take(free: Array, role: UnitKind.Role) -> DeckEntry:
	for i in free.size():
		if UnitKind.role((free[i] as DeckEntry).kind) == role:
			var entry: DeckEntry = free[i]
			free.remove_at(i)
			return entry
	return null


static func _hire(deck: Deck, kind: UnitKind.Id) -> void:
	if deck.total_cost() + UnitKind.cost(kind) <= deck.budget():
		deck.add(kind)


## その種類の駒に持たせる装備。持たせなければ -1。
static func _item_for(kind: UnitKind.Id) -> int:
	match UnitKind.role(kind):
		UnitKind.Role.VANGUARD:
			return Equipment.Id.IRON_SHIELD
		UnitKind.Role.RAIDER:
			return Equipment.Id.SPEED_BOOTS
	return -1
