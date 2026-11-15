extends RefCounted
## 取っておく部隊（名前を付けた編成）の一覧。読み書きは save_store.gd（user:// の JSON）。ノードに依存しない。
## 形式は docs/deck-library.md。
##
## - 部隊は、名前と、どの決まりで組んだか（DeckRules の id）と、編成（軍・駒・装備）を持つ。
## - 壊れたファイル・知らない駒や装備・知らない決まりがあっても、起動を止めない。読めたぶんだけ一覧に残し、
##   出せない理由（load_issues）を付ける。決まりが変わって検査を通らなくなった部隊も、一覧に「出せない」と理由つきで残す。
## - 一覧を変える関数（add、replace、duplicate_deck、rename、remove）は、変えたあと書く（store が null なら書かない）。

const SaveStore := preload("res://prototype/save_store.gd")
const DeckText := preload("res://prototype/deck_text.gd")

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

	## 対戦に出せない理由の文（空なら出せる）。
	func issues() -> Array[String]:
		var found: Array[String] = load_issues.duplicate()
		found.append_array(DeckText.problem_texts(deck))
		return found

	func playable() -> bool:
		return issues().is_empty()


## 取っておく先（null なら書かない。検査・自動の対戦・スクリーンショットでは null）。
var store: RefCounted
var _items: Array[Saved] = []
var _next_id := 1


## 取っておいた部隊を読む（いまの一覧は捨てる）。
func load_saved() -> void:
	_items.clear()
	_next_id = 1
	if store == null:
		return
	var saved: Dictionary = store.read(STORE_NAME)
	if saved.is_empty():
		changed.emit()
		return
	var data: Dictionary = _migrate(saved["version"], saved["data"])
	load_data(data)


## 中身（ファイルの data）から一覧を作る。形の違うところは読み飛ばす。
func load_data(data: Dictionary) -> void:
	_items.clear()
	_next_id = 1
	var next: Variant = data.get("next_id")
	if typeof(next) in [TYPE_INT, TYPE_FLOAT]:
		_next_id = maxi(1, int(next))
	var records: Variant = data.get("decks")
	if typeof(records) == TYPE_ARRAY:
		for record: Variant in records:
			if typeof(record) != TYPE_DICTIONARY:
				push_warning("deck_library: 部隊の形でないものを読み飛ばした")
				continue
			var item := _from_record(record)
			if item.id == "" or find(item.id) != null:
				item.id = _take_id()
			elif item.id.is_valid_int():
				_next_id = maxi(_next_id, int(item.id) + 1)
			_items.append(item)
	changed.emit()


## いまの一覧を書く。書けたか（書く先が無ければ偽）。
func save() -> bool:
	if store == null:
		return false
	return store.write(STORE_NAME, FORMAT_VERSION, to_data())


## ファイルの data に書く中身。
func to_data() -> Dictionary:
	var records: Array = []
	for item in _items:
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


## 新しい部隊を一覧の最後に足す（deck は写して持つ）。
func add(name: String, deck: Deck) -> Saved:
	var item := Saved.new()
	item.id = _take_id()
	item.name = clean_name(name, default_name())
	item.deck = deck.copy()
	_items.append(item)
	_commit()
	return item


## id の部隊の中身を deck（写して持つ）と name にする。読み込みのときの理由は消える。無ければ何もせず false。
func replace(id: String, name: String, deck: Deck) -> bool:
	var item := find(id)
	if item == null:
		return false
	item.name = clean_name(name, item.name)
	item.deck = deck.copy()
	item.load_issues.clear()
	_commit()
	return true


## id の部隊の写しを、そのすぐ後ろに足す。名前は「〜 の写し」。無ければ null。
func duplicate_deck(id: String) -> Saved:
	var index := _index_of(id)
	if index == -1:
		return null
	var original := _items[index]
	var item := Saved.new()
	item.id = _take_id()
	item.name = clean_name("%s の写し" % original.name, original.name)
	item.deck = original.deck.copy()
	item.load_issues = original.load_issues.duplicate()
	_items.insert(index + 1, item)
	_commit()
	return item


## id の部隊の名前を変える。空の名前なら変えない。無ければ false。
func rename(id: String, name: String) -> bool:
	var item := find(id)
	if item == null:
		return false
	item.name = clean_name(name, item.name)
	_commit()
	return true


## id の部隊を消す。無ければ false。
func remove(id: String) -> bool:
	var index := _index_of(id)
	if index == -1:
		return false
	_items.remove_at(index)
	_commit()
	return true


## まだ使っていない「部隊 N」の名前。
func default_name() -> String:
	var n := _items.size() + 1
	while _items.any(func(item: Saved) -> bool: return item.name == "部隊 %d" % n):
		n += 1
	return "部隊 %d" % n


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
	return {"rules": String(deck.rules.id), "army": UnitKind.Army.keys()[deck.army], "units": units}


## ファイルの 1 件から、取っておいた部隊を作る。知らない駒・装備は外し、知らない決まり・軍は理由に書く。
static func _from_record(record: Dictionary) -> Saved:
	var item := Saved.new()
	var kept: Variant = record.get("load_issues")
	if typeof(kept) == TYPE_ARRAY:
		for issue: Variant in kept:
			if typeof(issue) == TYPE_STRING and not item.load_issues.has(issue):
				item.load_issues.append(issue)
	var id: Variant = record.get("id")
	item.id = str(int(id)) if typeof(id) in [TYPE_INT, TYPE_FLOAT] else (id if typeof(id) == TYPE_STRING else "")
	var name: Variant = record.get("name")
	item.name = clean_name(name if typeof(name) == TYPE_STRING else "", "名前の無い部隊")
	var rules_name: Variant = record.get("rules")
	var rules: DeckRules = DeckRules.by_id(StringName(rules_name)) if typeof(rules_name) == TYPE_STRING else null
	if rules == null:
		item.load_issues.append("知らない決まり（%s）で組んである" % [rules_name if typeof(rules_name) == TYPE_STRING else "無し"])
		rules = DeckRules.versus()
	var army_name: Variant = record.get("army")
	var army := UnitKind.Army.NONE
	if typeof(army_name) == TYPE_STRING and UnitKind.Army.has(army_name):
		army = UnitKind.Army[army_name]
	if army == UnitKind.Army.NONE:
		item.load_issues.append("軍が読めない（%s）" % [army_name if typeof(army_name) == TYPE_STRING else "無し"])
	item.deck = Deck.new(army, rules)
	var units: Variant = record.get("units")
	if typeof(units) != TYPE_ARRAY:
		units = []
	for unit: Variant in units:
		if typeof(unit) != TYPE_DICTIONARY:
			item.load_issues.append("読めない駒を外した")
			continue
		var kind_name: Variant = unit.get("kind")
		if typeof(kind_name) != TYPE_STRING or not UnitKind.Id.has(kind_name):
			item.load_issues.append("知らない駒（%s）を外した" % [kind_name if typeof(kind_name) == TYPE_STRING else "無し"])
			continue
		# 検査（Deck.problems）で分かるよう、ロスターや数の上限は見ずに、そのまま並べる。
		var entry := DeckEntry.new(UnitKind.Id[kind_name])
		var equipment: Variant = unit.get("equipment")
		if typeof(equipment) == TYPE_ARRAY:
			for equipment_name: Variant in equipment:
				if typeof(equipment_name) == TYPE_STRING and Equipment.Id.has(equipment_name):
					entry.equipment.append(Equipment.Id[equipment_name])
				else:
					item.load_issues.append("知らない装備（%s）を外した" % [equipment_name if typeof(equipment_name) == TYPE_STRING else "無し"])
		item.deck.entries.append(entry)
	return item


## 古い形の中身を、いまの形に読み替える。いまは版 1 だけ。新しい版（後の版で書いたもの）は、同じ形として読めるところだけ読む。
static func _migrate(version: int, data: Dictionary) -> Dictionary:
	if version > FORMAT_VERSION:
		push_warning("deck_library: 新しい版（%d）のファイルを、版 %d として読む" % [version, FORMAT_VERSION])
	return data


func _commit() -> void:
	save()
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
