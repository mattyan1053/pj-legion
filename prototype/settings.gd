extends RefCounted
## 遊ぶ人ごとの設定（マウスの感度など）。項目の並び・範囲・既定の値と、いまの値を持つ。ノードに依存しない。
##
## 画面（settings_panel.gd）は ITEMS から行を作るので、項目を足すのは ITEMS に 1 つ足し、効かせる側
## （board_prototype.gd の _apply_settings）に 1 行足すだけで済む。
## 音量（BGM・効果音）は、音が入ったら、ITEMS に区分 "音" の SLIDER として足す。
##
## 取っておくのは save_store.gd（user:// の JSON）。読めないファイル・知らない項目・型の違う値・範囲の外の値は、
## 既定の値に戻すか、範囲に収める（起動を止めない）。

## 値が変わった（key は項目の名前）。
signal changed(key: StringName)

enum Kind { SLIDER, TOGGLE, CHOICE }

## save_store.gd で置くまとまりの名前と、中身の形の版（形を変えたら上げ、_migrate に読み替えを足す）。
const STORE_NAME := "settings"
const FORMAT_VERSION := 1

const MOUSE_SENSITIVITY := &"mouse_sensitivity"
const INVERT_VERTICAL_DRAG := &"invert_vertical_drag"
const CPU_PLAYBACK_SPEED := &"cpu_playback_speed"

## 項目（画面に並べる順）。
## - key: 名前（ファイルにも、この名前で書く）。section: 画面の区分の見出し。label: 項目の名前。note: 短い説明。
## - kind が SLIDER: 整数の min〜max を step 刻みで。unit は数のあとに付ける文字。
## - kind が TOGGLE: オン・オフ（bool）。
## - kind が CHOICE: choices（[値, 名前] の列）から 1 つ。
## - default: 既定の値。
const ITEMS: Array[Dictionary] = [
	{
		"key": MOUSE_SENSITIVITY, "section": "操作", "label": "マウスの感度",
		"note": "ドラッグで視点を回す・傾ける速さ",
		"kind": Kind.SLIDER, "min": 25, "max": 300, "step": 5, "unit": "%", "default": 100,
	},
	{
		"key": INVERT_VERTICAL_DRAG, "section": "操作", "label": "縦のドラッグを逆にする",
		"note": "オフ: 下へ動かすと真上から見下ろす。オン: 上へ動かすと真上から見下ろす",
		"kind": Kind.TOGGLE, "default": false,
	},
	{
		"key": CPU_PLAYBACK_SPEED, "section": "再生", "label": "CPU の番の速さ",
		"note": "CPU の駒が動く・攻撃するところを見せる速さ（中立の番は変わらない）",
		"kind": Kind.CHOICE, "choices": [[1, "ふつう"], [2, "速い"], [3, "とても速い"]], "default": 1,
	},
]

var _values := {}
## 取っておく先（null なら取っておかない。検査・自動の対戦・スクリーンショットでは null にする）。
var store: RefCounted


func _init() -> void:
	reset_all()


## 項目の定義（ITEMS の 1 つ）。無ければ空。
static func item(key: StringName) -> Dictionary:
	for entry in ITEMS:
		if entry["key"] == key:
			return entry
	return {}


static func keys() -> Array[StringName]:
	var found: Array[StringName] = []
	for entry in ITEMS:
		found.append(entry["key"])
	return found


func value(key: StringName) -> Variant:
	return _values.get(key)


## key の値を value にする（範囲に収め、刻みにそろえる。型が違えば何もしない）。変わったら changed を出す。
func set_value(key: StringName, new_value: Variant) -> void:
	var entry := item(key)
	if entry.is_empty():
		return
	var normalized: Variant = normalize(entry, new_value)
	if normalized == null or normalized == _values.get(key):
		return
	_values[key] = normalized
	changed.emit(key)


func default_value(key: StringName) -> Variant:
	return item(key).get("default")


func is_default(key: StringName) -> bool:
	return _values.get(key) == default_value(key)


func reset(key: StringName) -> void:
	set_value(key, default_value(key))


func reset_all() -> void:
	for entry in ITEMS:
		if _values.get(entry["key"]) != entry["default"]:
			_values[entry["key"]] = entry["default"]
			changed.emit(entry["key"])


## 項目 entry に入れられる形に直した値。直せない（型が違う、選択肢に無い）なら null。
static func normalize(entry: Dictionary, raw: Variant) -> Variant:
	match entry["kind"]:
		Kind.SLIDER:
			if typeof(raw) not in [TYPE_INT, TYPE_FLOAT] or is_nan(float(raw)) or is_inf(float(raw)):
				return null
			var step: int = entry["step"]
			var snapped := int(roundf((float(raw) - entry["min"]) / step)) * step + int(entry["min"])
			return clampi(snapped, entry["min"], entry["max"])
		Kind.TOGGLE:
			return raw if typeof(raw) == TYPE_BOOL else null
		Kind.CHOICE:
			if typeof(raw) not in [TYPE_INT, TYPE_FLOAT]:
				return null
			for choice: Array in entry["choices"]:
				if is_equal_approx(float(choice[0]), float(raw)):
					return choice[0]
			return null
	return null


## 値の見せ方（スライダーの横の文字など）。
static func value_text(entry: Dictionary, shown: Variant) -> String:
	match entry["kind"]:
		Kind.SLIDER:
			return "%d%s" % [shown, entry.get("unit", "")]
		Kind.TOGGLE:
			return "オン" if shown else "オフ"
		Kind.CHOICE:
			for choice: Array in entry["choices"]:
				if choice[0] == shown:
					return choice[1]
	return str(shown)


## ファイルに書く形（名前 -> 値）。
func to_dict() -> Dictionary:
	var data := {}
	for entry in ITEMS:
		data[String(entry["key"])] = _values[entry["key"]]
	return data


## ファイルから読んだ形（名前 -> 値）を入れる。知らない名前は捨て、無い・直せない値は既定の値にする。
func from_dict(data: Dictionary) -> void:
	for entry in ITEMS:
		var raw: Variant = data.get(String(entry["key"]))
		var normalized: Variant = normalize(entry, raw) if raw != null else null
		set_value(entry["key"], normalized if normalized != null else entry["default"])


## store から読む（無い・読めないなら、既定の値のまま）。
func load_saved() -> void:
	if store == null:
		return
	var saved: Dictionary = store.read(STORE_NAME)
	if saved.is_empty():
		return
	from_dict(_migrate(saved["version"], saved["data"]))


## store へ書く。書けたかを返す（store が無ければ偽）。
func save() -> bool:
	return store != null and store.write(STORE_NAME, FORMAT_VERSION, to_dict())


## 版 version の中身を、いまの形に読み替える。いまは版 1 だけなので、そのまま返す。
## 新しい版（この版より後のもので書かれた）でも、知っている名前は読む（from_dict が知らない名前を捨てる）。
static func _migrate(_version: int, data: Dictionary) -> Dictionary:
	return data
