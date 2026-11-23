class_name CpuDeck
extends RefCounted
## CPU の編成（docs/cpu-ai.md）。軍を渡すと、その軍のロスターと予算に収まる、対戦に出せる編成を作る。
## 決まり（DeckRules）を渡さなければ、対戦の決まりで組む。
##
## 乱数は使わない。同じ軍からは、いつも同じ編成になる。
## 1. 4 つの役割（前衛・後衛・奇襲・回復）を 1 体ずつ雇う
## 2. 予算と数の上限が許すかぎり、前衛、後衛、奇襲の順にもう 1 体ずつ足す
## 3. 余った予算で装備を持たせる。前衛にアイアンシールド、奇襲にスピードブーツを、1 個ずつ順に配る
## 4. 誓いを結べる軍（騎士領）なら、誓いを結ぶ（oath_plan。組み方が入の対戦で効く。docs/formation.md）


## 縫い目の様子の札に合う駒 1 体ぶんの値（sign_fit）。
const SIGN_FIT := 1


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
	bind_oaths(deck)
	return deck


## 騎士領の編成に、CPU の決め方で誓いを結ぶ（もう結んである誓いはほどく）。騎士領でなければ何もしない。
## 誓いは、近くで戦う 2 人で結ぶ（仇討ちは、相手が近くにいる間だけ効く）。
## 1 組目は前衛と後衛（前衛が受けた敵を、後ろから撃ち返す）。2 組目は、残りの前衛か奇襲と、残りの後衛か前衛。
## 回復役は結ばない（攻撃しないので、仇討ちが効かない）。
static func bind_oaths(deck: Deck) -> void:
	deck.oaths.clear()
	if not Formation.binds_oaths(deck.army):
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


## 縫い目の様子の札 signs（Seam.Sign の並び）を見て、候補 candidates から出す部隊を選ぶ（docs/cpu-ai.md の「縫い目の様子」）。
## いちばん札に合う（sign_fit が高い）もの。並べば先の候補（候補の先頭に、いつもの部隊を置けば、札に関わらないときはそれを出す）。
## 候補が空なら null。札が無ければ先頭。
static func pick_for_signs(candidates: Array[Deck], signs: Array[int]) -> Deck:
	var best: Deck = null
	var best_fit := 0
	for deck in candidates:
		var fit := sign_fit(deck, signs)
		if best == null or fit > best_fit:
			best = deck
			best_fit = fit
	return best


## 部隊 deck が札 signs に合う度合い（高いほど合う）。駒 1 体ずつ、札が得にする駒を足し、損にする駒を引く。
## - 天裂の名残り: 射程が Seam.HAZE_FROM 以上の駒（スナイパー）は射程が縮むので -SIGN_FIT
## - 天裂の光: 後衛は射程が伸びるので +SIGN_FIT
## ほかの札は、どの部隊にも同じくらいに効くので数えない。
static func sign_fit(deck: Deck, signs: Array[int]) -> int:
	var fit := 0
	for entry in deck.entries:
		var role := UnitKind.role(entry.kind)
		if signs.has(Seam.Sign.HAZE) and UnitKind.attack_range(entry.kind) >= Seam.HAZE_FROM:
			fit -= SIGN_FIT
		if signs.has(Seam.Sign.GLEAM) and role == UnitKind.Role.REARGUARD:
			fit += SIGN_FIT
	return fit
