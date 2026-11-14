class_name CpuDeck
extends RefCounted
## CPU の編成（docs/cpu-ai.md）。軍を渡すと、その軍のロスターと予算に収まる、対戦に出せる編成を作る。
##
## 乱数は使わない。同じ軍からは、いつも同じ編成になる。
## 1. 4 つの役割（前衛・後衛・奇襲・回復）を 1 体ずつ雇う
## 2. 予算と数の上限が許すかぎり、前衛、後衛、奇襲の順にもう 1 体ずつ足す
## 3. 余った予算で装備を持たせる。前衛にアイアンシールド、奇襲にスピードブーツを、1 個ずつ順に配る


static func build(army: UnitKind.Army) -> Deck:
	var deck := Deck.new(army)
	var roster := Deck.roster(army)
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
	return deck


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
