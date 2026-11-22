extends RefCounted
## 取っておく部隊（名前を付けた編成）の一覧。読み書きは save_store.gd（user:// の JSON）。ノードに依存しない。
## 形式は docs/deck-library.md。
##
## - 部隊は、名前と、どの決まりで組んだか（DeckRules の id）と、編成（軍・駒・装備）を持つ。
## - 壊れたファイル・知らない駒や装備・知らない決まりがあっても、起動を止めない。読めたぶんだけ一覧に残し、
##   出せない理由（load_issues）を付ける。決まりが変わって検査を通らなくなった部隊も、一覧に「出せない」と理由つきで残す。
## - 一覧を変える関数（add、replace、duplicate_deck、rename、remove）は、変えたあと書く（store が null なら書かない）。
## - 対戦用の部隊は store（user://decks.json）に、ストーリー用の部隊は slot_store（いまのセーブのスロット。save_slots.gd）に書く。
##   どちらに書くかは、部隊の決まり（is_slot_rules）で決める。slot_store が無ければ、全部を store に書く。

const Text := preload("res://game/text.gd")
const SaveStore := preload("res://game/save_store.gd")
const DeckText := preload("res://game/deck_text.gd")

## 一覧が変わった。
signal changed

## save_store.gd で置くまとまりの名前と、中身の形の版（形を変えたら上げ、_migrate に読み替えを足す）。
const STORE_NAME := "decks"
const FORMAT_VERSION := 1
## 名前の長さの上限（文字）。
const MAX_NAME_LENGTH := 20


## 取っておいた部隊 1 つ。
class Saved:
	extends RefCounted
	## 一覧の中で変わらない名前（ファイルに書く）。
	var id: String
	var name: String
	var deck: Deck
	## 読み込んだときに見つかった、出せない理由（知らない駒を外した、など）。組み直して取っておけば消える。
	var load_issues: Array[String] = []
	## セーブのスロットに書くか（ストーリー用の部隊）。
	var in_slot := false

	## 対戦に出せない理由の文（空なら出せる）。
	func issues() -> Array[String]:
		var found: Array[String] = load_issues.duplicate()
		found.append_array(DeckText.problem_texts(deck))
		return found

	func playable() -> bool:
		return issues().is_empty()


## 取っておく先（null なら書かない。検査・自動の対戦・スクリーンショットでは null）。
var store: RefCounted
## 決まりの名前から決まり（DeckRules）を引くもの（名前 -> DeckRules か null）。既定は DeckRules.by_id（対戦の決まりだけ）。
## ストーリーの決まりは進み具合で変わるので、アプリ（app_context.gd）が、ストーリーの決まりも引けるものを入れる。
var rules_lookup: Callable = DeckRules.by_id
## ストーリー用の部隊を書く先（いまのセーブのスロットのまとまり。save_slots.gd の section()）。null なら、全部を store に書く。
var slot_store: RefCounted
## 決まりの名前（StringName）が、スロットに書く決まり（ストーリーの決まり）か。アプリ（app_context.gd）が入れる。
var is_slot_rules: Callable = func(_id: StringName) -> bool: return false
var _items: Array[Saved] = []
var _next_id := 1


## 取っておいた部隊を読む（いまの一覧は捨てる）。
## 対戦用は store から、ストーリー用は slot_store から読む。store に残っていたストーリー用の部隊（前の置き方のもの）は、
## いまのスロットへ移して書き直す。
func load_saved() -> void:
	_items.clear()
	_next_id = 1
	var data := {}
	if store != null:
		var saved: Dictionary = store.read(STORE_NAME)
		if not saved.is_empty():
			data = _migrate(saved["version"], saved["data"])
	var moved := false
	if slot_store != null:
		var in_slot: Dictionary = slot_store.read(STORE_NAME)
		var slot_data := {} if in_slot.is_empty() else _migrate(in_slot["version"], in_slot["data"])
		var records: Array = []
		var global_records: Variant = data.get("decks")
		if typeof(global_records) == TYPE_ARRAY:
			for record: Variant in global_records:
				records.append(record)
				if typeof(record) == TYPE_DICTIONARY and typeof(record.get("rules")) == TYPE_STRING and is_slot_rules.call(StringName(record["rules"])):
					moved = true
		var first_slot := records.size()
		var slot_records: Variant = slot_data.get("decks")
		if typeof(slot_records) == TYPE_ARRAY:
			records.append_array(slot_records)
		var next: Variant = slot_data.get("next_id")
		if typeof(next) in [TYPE_INT, TYPE_FLOAT] and (typeof(data.get("next_id")) not in [TYPE_INT, TYPE_FLOAT] or int(next) > int(data["next_id"])):
			data["next_id"] = int(next)
		data["decks"] = records
		load_data(data, first_slot)
	else:
		load_data(data)
	if moved:
		save()


## 中身（ファイルの data）から一覧を作る。形の違うところは読み飛ばす。
## first_slot より後ろ（番号がそれ以上）の部隊は、セーブのスロットから読んだもの（in_slot）。前の部隊は、決まりで分ける。
func load_data(data: Dictionary, first_slot := -1) -> void:
	_items.clear()
	_next_id = 1
	var next: Variant = data.get("next_id")
	if typeof(next) in [TYPE_INT, TYPE_FLOAT]:
		_next_id = maxi(1, int(next))
	var records: Variant = data.get("decks")
	if typeof(records) == TYPE_ARRAY:
		for index: int in (records as Array).size():
			var record: Variant = records[index]
			if typeof(record) != TYPE_DICTIONARY:
				push_warning("deck_library: 部隊の形でないものを読み飛ばした")
				continue
			var item := _from_record(record, rules_lookup)
			var rules_name: Variant = record.get("rules")
			item.in_slot = (first_slot >= 0 and index >= first_slot) or (typeof(rules_name) == TYPE_STRING and is_slot_rules.call(StringName(rules_name)))
			if item.id == "" or find(item.id) != null:
				item.id = _take_id()
			elif item.id.is_valid_int():
				_next_id = maxi(_next_id, int(item.id) + 1)
			_items.append(item)
	changed.emit()


## いまの一覧を書く（対戦用とストーリー用の両方）。書けたか（書く先が無ければ偽）。
func save() -> bool:
	if slot_store == null:
		return store != null and store.write(STORE_NAME, FORMAT_VERSION, to_data())
	# ストーリー用を先に書く。書けなければ（スロットが壊れている、など）、対戦用のファイルも書き直さない
	# （前の置き方で対戦用のファイルに残っていたストーリー用の部隊を、どこにも書かずに落とさないため）。
	# ストーリー用の部隊が無く、スロットもまだ始めていなければ、スロットは書かない（対戦用の部隊を取っておいただけで、
	# 空のスロットが「つづきから」にならないように。次に付ける id の番号は、対戦用のファイルが持つ）。
	var has_slot_items := _items.any(func(item: Saved) -> bool: return item.in_slot)
	var slot_ok := true
	if has_slot_items or not slot_store.has_method(&"is_started") or slot_store.is_started():
		slot_ok = _save_part(true)
	if not slot_ok and has_slot_items:
		return false
	return _save_part(false) and slot_ok


## 対戦用（in_slot が偽）か、ストーリー用（真）の部隊だけを書く。次に付ける id の番号は、両方に書く（スロットを替えても重ならないように）。
func _save_part(in_slot: bool) -> bool:
	var target: RefCounted = slot_store if in_slot else store
	if target == null:
		return false
	return target.write(STORE_NAME, FORMAT_VERSION, to_data(1 if in_slot else 0))


## ファイルの data に書く中身。part が -1 なら全部、0 なら対戦用（スロットの外）、1 ならストーリー用（スロット）の部隊だけ。
func to_data(part := -1) -> Dictionary:
	var records: Array = []
	for item in _items:
		if part != -1 and item.in_slot != (part == 1):
			continue
		var record := deck_to_record(item.deck)
		record["id"] = item.id
		record["name"] = item.name
		if not item.load_issues.is_empty():
			# 読み込みで外した・読み替えたものの理由は、組み直して取っておくまで残す（書き直しで出せるようにならない）。
			record["load_issues"] = item.load_issues.duplicate()
		records.append(record)
	return {"next_id": _next_id, "decks": records}


## 取っておいた部隊（並びは一覧の順）。
func items() -> Array[Saved]:
	return _items.duplicate()


func size() -> int:
	return _items.size()


func find(id: String) -> Saved:
	for item in _items:
		if item.id == id:
			return item
	return null


## 決まり rules_id で組んだ部隊のうち、軍が army のもの（army が NONE なら全部）。出せないものも入る。
func for_rules(rules_id: StringName, army := UnitKind.Army.NONE) -> Array[Saved]:
	var found: Array[Saved] = []
	for item in _items:
		if item.deck.rules.id == rules_id and (army == UnitKind.Army.NONE or item.deck.army == army):
			found.append(item)
	return found


## 部隊の決まりを、rules_lookup で引き直す（ストーリーの進み具合が変わって、雇える駒が増えたとき）。
## 引けない決まり（読み込みで知らなかった決まり）の部隊は、そのまま。ファイルには書かない（決まりの名前は変わらない）。
func refresh_rules() -> void:
	for item in _items:
		var rules: DeckRules = rules_lookup.call(item.deck.rules.id)
		if rules != null:
			item.deck.rules = rules
	changed.emit()


## 新しい部隊を一覧の最後に足す（deck は写して持つ）。
func add(name: String, deck: Deck) -> Saved:
	var item := Saved.new()
	item.id = _take_id()
	item.name = clean_name(name, default_name())
	item.deck = deck.copy()
	item.in_slot = slot_store != null and is_slot_rules.call(deck.rules.id)
	_items.append(item)
	_commit(item, true)
	return item


## id の部隊の中身を deck（写して持つ）と name にする。読み込みのときの理由は消える。無ければ何もせず false。
func replace(id: String, name: String, deck: Deck) -> bool:
	var item := find(id)
	if item == null:
		return false
	item.name = clean_name(name, item.name)
	item.deck = deck.copy()
	item.load_issues.clear()
	_commit(item)
	return true


## id の部隊の写しを、そのすぐ後ろに足す。名前は「〜 の写し」。無ければ null。
func duplicate_deck(id: String) -> Saved:
	var index := _index_of(id)
	if index == -1:
		return null
	var original := _items[index]
	var item := Saved.new()
	item.id = _take_id()
	item.name = clean_name(Text.t("deck.name.copy", {"name": original.name}), original.name)
	item.deck = original.deck.copy()
	item.load_issues = original.load_issues.duplicate()
	item.in_slot = original.in_slot
	_items.insert(index + 1, item)
	_commit(item, true)
	return item


## id の部隊の名前を変える。空の名前なら変えない。無ければ false。
func rename(id: String, name: String) -> bool:
	var item := find(id)
	if item == null:
		return false
	item.name = clean_name(name, item.name)
	_commit(item)
	return true


## id の部隊を消す。無ければ false。
func remove(id: String) -> bool:
	var index := _index_of(id)
	if index == -1:
		return false
	var removed := _items[index]
	_items.remove_at(index)
	_commit(removed)
	return true


## まだ使っていない「部隊 N」の名前。
func default_name() -> String:
	var n := _items.size() + 1
	while _items.any(func(item: Saved) -> bool: return item.name == Text.t("deck.name.default", {"number": n})):
		n += 1
	return Text.t("deck.name.default", {"number": n})


## 名前を整える（前後の空白と改行を落とし、長さを切り詰める）。空になったら fallback。
static func clean_name(name: String, fallback: String) -> String:
	var cleaned := name.replace("\n", " ").replace("\t", " ").strip_edges()
	if cleaned.length() > MAX_NAME_LENGTH:
		cleaned = cleaned.substr(0, MAX_NAME_LENGTH)
	return cleaned if cleaned != "" else fallback


# ---- 編成と、ファイルの形 ----


## 編成を、ファイルに書く形にする。駒・装備・軍は、列挙の名前（"SNIPER" など）で書く（番号は並べ替えで変わるため）。
static func deck_to_record(deck: Deck) -> Dictionary:
	var units: Array = []
	for entry in deck.entries:
		var equipment: Array = []
		for item in entry.equipment:
			equipment.append(Equipment.Id.keys()[item])
		units.append({"kind": UnitKind.Id.keys()[entry.kind], "equipment": equipment})
	var record := {"rules": String(deck.rules.id), "army": UnitKind.Army.keys()[deck.army], "units": units}
	if not deck.oaths.is_empty():
		# 誓い（組み方。docs/formation.md）は、駒の並びの添字の組で書く。
		var oaths: Array = []
		for pair in deck.oath_pairs():
			oaths.append([pair.x, pair.y])
		record["oaths"] = oaths
	return record


## ファイルの 1 件から、取っておいた部隊を作る。知らない駒・装備は外し、知らない決まり・軍は理由に書く。
## lookup は決まりの名前から決まりを引くもの（rules_lookup）。
static func _from_record(record: Dictionary, lookup: Callable = DeckRules.by_id) -> Saved:
	var item := Saved.new()
	var kept: Variant = record.get("load_issues")
	if typeof(kept) == TYPE_ARRAY:
		for issue: Variant in kept:
			if typeof(issue) == TYPE_STRING and not item.load_issues.has(issue):
				item.load_issues.append(issue)
	var id: Variant = record.get("id")
	item.id = str(int(id)) if typeof(id) in [TYPE_INT, TYPE_FLOAT] else (id if typeof(id) == TYPE_STRING else "")
	var name: Variant = record.get("name")
	item.name = clean_name(name if typeof(name) == TYPE_STRING else "", Text.t("deck.name.unnamed"))
	var rules_name: Variant = record.get("rules")
	var rules: DeckRules = lookup.call(StringName(rules_name)) if typeof(rules_name) == TYPE_STRING else null
	if rules == null:
		item.load_issues.append(Text.t("deck.load.unknown_rules", {"name": _shown(rules_name)}))
		rules = DeckRules.versus()
	var army_name: Variant = record.get("army")
	var army := UnitKind.Army.NONE
	if typeof(army_name) == TYPE_STRING and UnitKind.Army.has(army_name):
		army = UnitKind.Army[army_name]
	if army == UnitKind.Army.NONE:
		item.load_issues.append(Text.t("deck.load.unknown_army", {"name": _shown(army_name)}))
	item.deck = Deck.new(army, rules)
	var units: Variant = record.get("units")
	if typeof(units) != TYPE_ARRAY:
		units = []
	for unit: Variant in units:
		if typeof(unit) != TYPE_DICTIONARY:
			item.load_issues.append(Text.t("deck.load.unreadable_unit"))
			continue
		var kind_name: Variant = unit.get("kind")
		if typeof(kind_name) != TYPE_STRING or not UnitKind.Id.has(kind_name):
			item.load_issues.append(Text.t("deck.load.unknown_unit", {"name": _shown(kind_name)}))
			continue
		# 検査（Deck.problems）で分かるよう、ロスターや数の上限は見ずに、そのまま並べる。
		var entry := DeckEntry.new(UnitKind.Id[kind_name])
		var equipment: Variant = unit.get("equipment")
		if typeof(equipment) == TYPE_ARRAY:
			for equipment_name: Variant in equipment:
				if typeof(equipment_name) == TYPE_STRING and Equipment.Id.has(equipment_name):
					entry.equipment.append(Equipment.Id[equipment_name])
				else:
					item.load_issues.append(Text.t("deck.load.unknown_item", {"name": _shown(equipment_name)}))
		item.deck.entries.append(entry)
	# 誓い（無ければ空。読めない組と、結べない組は捨てる。理由には書かない: 部隊は出撃できる）。
	var oaths: Variant = record.get("oaths")
	if typeof(oaths) == TYPE_ARRAY:
		for pair: Variant in oaths:
			if typeof(pair) != TYPE_ARRAY or (pair as Array).size() != 2:
				continue
			var a: Variant = pair[0]
			var b: Variant = pair[1]
			if typeof(a) not in [TYPE_INT, TYPE_FLOAT] or typeof(b) not in [TYPE_INT, TYPE_FLOAT]:
				continue
			var count := item.deck.entries.size()
			if int(a) >= 0 and int(a) < count and int(b) >= 0 and int(b) < count:
				item.deck.bind(item.deck.entries[int(a)], item.deck.entries[int(b)])
	return item


## 古い形の中身を、いまの形に読み替える。いまは版 1 だけ。新しい版（後の版で書いたもの）は、同じ形として読めるところだけ読む。
static func _migrate(version: int, data: Dictionary) -> Dictionary:
	if version > FORMAT_VERSION:
		push_warning("deck_library: 新しい版（%d）のファイルを、版 %d として読む" % [version, FORMAT_VERSION])
	return data


## item の側（対戦用か、ストーリー用か）を書く。新しい id を付けたら、もう片方にも次の番号を書く。
func _commit(item: Saved, took_id := false) -> void:
	if slot_store == null or took_id:
		save()
	else:
		_save_part(item.in_slot)
	changed.emit()


func _take_id() -> String:
	var id := str(_next_id)
	_next_id += 1
	while find(id) != null:
		id = str(_next_id)
		_next_id += 1
	return id


func _index_of(id: String) -> int:
	for i in _items.size():
		if _items[i].id == id:
			return i
	return -1


## 読めなかった値を、理由の文に出す形（文字でなければ「無し」）。
static func _shown(value: Variant) -> String:
	return value if typeof(value) == TYPE_STRING else Text.t("deck.load.none")
