extends RefCounted
## セーブのスロット（docs/save-slots.md）。ストーリーの進み具合とストーリー用の部隊を、スロットごとに 1 つのファイルにまとめる。
## ノードに依存しない。
##
## - スロットは COUNT 個。ファイルは save_store.gd の名前 "slot_<番号>"（user://slot_1.json など）。
##   中身は {"saved_at": 最後に書いた時刻, "played_seconds": 遊んだ時間, "sections": {まとまりの名前: {"version", "data"}}}。
##   まとまりは、ストーリーの進み具合（"story"。story.gd）とストーリー用の部隊（"decks"。deck_library.gd）。
## - いまのスロット（current）を 1 つ持つ。story.gd と deck_library.gd は section() を取っておく先にして、
##   ふつうのファイルと同じように読み書きする。
## - **ファイルに書くのは、決まった区切りだけ**（オートセーブ。docs/save-slots.md の「保存する所」）。
##   ストーリーの進み具合は section(true) で受け、覚えておくだけにする（話の流れを終えたときなど、アプリが flush で書く）。
##   部隊（「編成完了」など）は section() で受け、受けたらすぐ書く。ウィンドウを閉じた瞬間のものは書かない。
## - 設定と対戦用の部隊は、スロットに入れない（どのスロットで遊んでも同じ）。
## - 壊れたファイル・新しい版のファイルのスロットは、読まない・勝手に書かない（消すか、写して上書きするまで、そのまま残す）。
## - 取っておく先（store）が無いとき（検査・スクリーンショット）は、ファイルを書かずに、覚えておくだけ。

const SaveStore := preload("res://game/save_store.gd")

## スロットの中身が変わった（書いた、写した、消した）。
signal changed
## いまのスロットをファイルに書いた（保存の小さな印を出す）。
signal saved

## スロットの数。
const COUNT := 3
## スロットのファイルの中身の版（形を変えたら上げ、_migrate に読み替えを足す）。
const FORMAT_VERSION := 1
## スロットのファイルの名前の頭（後ろに番号）。
const PREFIX := "slot_"
## スロットの前の置き方（ストーリーの進み具合と部隊が、スロットの外の 1 つずつのファイルだった）の名前と、
## 移し替えたあとに前のファイルを残しておく名前の後ろ。
const OLD_STORY := "story"
const OLD_DECKS := "decks"
const BEFORE_SLOTS := "-before-slots"

## スロットの状態。
const EMPTY := &"empty"
const READY := &"ready"
const BROKEN := &"broken"
const NEWER := &"newer"

## 取っておく先（save_store.gd。null なら、ファイルを書かずに覚えておくだけ）。
var store: RefCounted
## いまのスロットの番号（1〜COUNT）。
var current := 1
## ストーリーを遊んでいる間、遊んだ時間を数えるか（app.gd が場面に合わせて入れる）。
var counting := false:
	set(value):
		if value == counting:
			return
		_take_time()
		counting = value

## 覚えているだけで、まだ書いていない変わりがあるか。
var _dirty := false
## いまのスロットを開いたか（select か open_latest のあと。開く前の中身は、どのスロットのものでもない）。
var _opened := false
## いまのスロットのまとまり（名前 -> {"version", "data"}）と、遊んだ時間（秒）、最後に書いた時刻。
var _sections := {}
var _played := 0.0
var _saved_at := 0
## いまのスロットにファイルがあるか（一度でも書いたか）。
var _started := false
## いまのスロットが、壊れている・新しい版で、書いてはいけないか。
var _locked := false
## 時間を数え始めた時刻（Time.get_ticks_msec）。
var _clock_from := 0
## store が無いときの、スロットの中身（番号 -> ファイルの data と同じ形）。
var _memory := {}
## 時刻を返すもの（検査で替える）。
var now: Callable = func() -> int: return int(Time.get_unix_time_from_system())


## スロット number のファイルの名前。
static func store_name(number: int) -> String:
	return "%s%d" % [PREFIX, number]


## いまのスロットのまとまりを読み書きするもの（story.gd と deck_library.gd の取っておく先）。
## buffered が真なら、受けた中身を覚えておくだけで、ファイルには書かない（次の flush で書く）。
func section(buffered := false) -> Section:
	return Section.new(self, buffered)


## 最後にファイルに書いた時刻（Unix 時刻。まだ書いていなければ 0）。
func saved_at() -> int:
	return _saved_at if _started else 0


## 覚えているだけで、まだファイルに書いていない変わりがあるか。
func has_unsaved() -> bool:
	return _dirty


# ---- スロットの状態 ----


## スロット number の様子: {"state": EMPTY / READY / BROKEN / NEWER, "saved_at": 時刻, "played_seconds": 秒, "sections": まとまり}。
## 時刻・時間・まとまりは READY のときだけ。いまのスロットは、書く前の時間も足して返す。
func info(number: int) -> Dictionary:
	var found := _read(number)
	if found["state"] != READY:
		return found
	if number == current:
		found["played_seconds"] = played_seconds()
	return found


## いまのスロットで遊んだ時間（秒。数えている途中のぶんも足す）。
func played_seconds() -> int:
	var running := 0.0
	if counting:
		running = (Time.get_ticks_msec() - _clock_from) / 1000.0
	return int(_played + running)


## いまのスロットに、もう書いたものがあるか。
func is_started() -> bool:
	return _started


## 中身のあるスロット（READY）があるか。
func any_ready() -> bool:
	for number in range(1, COUNT + 1):
		if _read(number)["state"] == READY:
			return true
	return false


# ---- 選ぶ・始める・写す・消す ----


## スロット number をいまのスロットにする。中身があれば読み、空なら新しく始める（すぐ書く）。
## 壊れている・新しい版のスロットは選べない（false）。
func select(number: int) -> bool:
	if number < 1 or number > COUNT:
		return false
	var found := _read(number)
	if found["state"] in [BROKEN, NEWER]:
		return false
	_take_time()
	if _opened and number == current and not _locked:
		# いまのスロットを選び直した: 読み直さず、覚えている中身（まだ書いていない進み具合も）のまま続ける。
		# まだ書いていなければ（はじめから）、ここで書く。
		if _dirty or not _started:
			flush()
		return true
	current = number
	_locked = false
	_dirty = false
	_opened = true
	if found["state"] == READY:
		_sections = (found["sections"] as Dictionary).duplicate(true)
		_played = float(found["played_seconds"])
		_saved_at = found["saved_at"]
		_started = true
	else:
		_sections = {}
		_played = 0.0
		_saved_at = 0
		_started = false
		flush()
	changed.emit()
	return true


## 起動したときのスロット: 最後に書いたスロット（中身のあるものの中で）。無ければ 1 番（空のまま。書くまでファイルは作らない）。
func open_latest() -> void:
	_opened = false  # 選び直しの近道を使わず、いつもファイルから読む
	var best := -1
	var best_time := -1
	for number in range(1, COUNT + 1):
		var found := _read(number)
		if found["state"] == READY and found["saved_at"] > best_time:
			best = number
			best_time = found["saved_at"]
	if best == -1:
		# 中身のあるスロットが無い: 空きの最初のスロット（壊れたスロットには書かない）。空きも無ければ 1 番を、書かないまま使う。
		current = 1
		for number in range(COUNT, 0, -1):
			if _read(number)["state"] == EMPTY:
				current = number
		_sections = {}
		_played = 0.0
		_saved_at = 0
		_started = false
		_locked = _read(current)["state"] != EMPTY
		_dirty = false
		_opened = true
		return
	select(best)


## スロット from の中身を、スロット to へ写す（to にあれば置き換える。最後に保存した日時とプレイ時間も写す）。写せたか。壊れている・新しい版のスロットからは写さない。
## to がいまのスロットなら、いまのスロットも写した中身になる（呼んだ側が、ストーリーと部隊を読み直す）。
func copy(from: int, to: int) -> bool:
	if from == to or from < 1 or from > COUNT or to < 1 or to > COUNT:
		return false
	if from == current:
		flush()
	var found := _read(from)
	if found["state"] != READY:
		return false
	var data := {"saved_at": found["saved_at"], "played_seconds": found["played_seconds"], "sections": (found["sections"] as Dictionary).duplicate(true)}
	if not _write(to, data):
		return false
	if to == current:
		_sections = data["sections"].duplicate(true)
		_played = float(data["played_seconds"])
		_saved_at = data["saved_at"]
		_started = true
		_locked = false
		_dirty = false
		_clock_from = Time.get_ticks_msec()
	changed.emit()
	return true


## スロット number を消す（壊れたファイルも消せる）。いまのスロットなら、いまのスロットも空になる（呼んだ側が読み直す）。
func remove(number: int) -> void:
	if number < 1 or number > COUNT:
		return
	if store == null:
		_memory.erase(number)
	else:
		store.remove(store_name(number))
	if number == current:
		_sections = {}
		_played = 0.0
		_saved_at = 0
		_started = false
		_locked = false
		_dirty = false
		_clock_from = Time.get_ticks_msec()
	changed.emit()


## いまのスロットを書く（遊んだ時間と時刻も）。書いてはいけないスロット（壊れている・新しい版）なら書かない。書けたか。
func flush() -> bool:
	if _locked:
		return false
	_take_time()
	_saved_at = now.call()
	var data := {"saved_at": _saved_at, "played_seconds": int(_played), "sections": _sections.duplicate(true)}
	if not _write(current, data):
		return false
	_started = true
	_dirty = false
	changed.emit()
	saved.emit()
	return true


## 始めていれば書く（場面を切り替えたとき、アプリを閉じるとき。遊んだ時間を残す）。
func flush_if_started() -> void:
	if _started:
		flush()


# ---- まとまり（Section が使う） ----


func _read_section(name: String) -> Dictionary:
	var found: Variant = _sections.get(name)
	if typeof(found) != TYPE_DICTIONARY:
		return {}
	var version: Variant = found.get("version")
	var data: Variant = found.get("data")
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or typeof(data) != TYPE_DICTIONARY:
		return {}
	return {"version": int(version), "data": (data as Dictionary).duplicate(true)}


func _write_section(name: String, version: int, data: Dictionary, buffered: bool) -> bool:
	if _locked:
		return false
	_sections[name] = {"version": version, "data": data.duplicate(true)}
	if buffered:
		_dirty = true
		return true
	return flush()


# ---- 前の置き方からの移し替え ----


## スロットの前の置き方（user://story.json と、user://decks.json の中のストーリー用の部隊）を、1 番のスロットへ移す。
## スロットのファイルが 1 つでもあれば何もしない。前のファイルは消さずに "<名前>-before-slots" として残す。
## is_slot_rules は、部隊の決まりの名前（String）がスロットに入れる決まり（ストーリー）か。移したか。
func migrate_old(is_slot_rules: Callable) -> bool:
	if store == null:
		return false
	for number in range(1, COUNT + 1):
		if store.exists(store_name(number)):
			return false
	var old_story: Dictionary = store.inspect(OLD_STORY)
	var old_decks: Dictionary = store.inspect(OLD_DECKS)
	var story_decks: Array = []
	var versus_decks: Array = []
	if old_decks["state"] == SaveStore.OK_STATE:
		var records: Variant = old_decks["data"].get("decks")
		if typeof(records) == TYPE_ARRAY:
			for record: Variant in records:
				var rules: Variant = record.get("rules") if typeof(record) == TYPE_DICTIONARY else null
				if typeof(rules) == TYPE_STRING and is_slot_rules.call(rules):
					story_decks.append(record)
				else:
					versus_decks.append(record)
	if old_story["state"] != SaveStore.OK_STATE and story_decks.is_empty():
		return false
	var sections := {}
	if old_story["state"] == SaveStore.OK_STATE:
		sections[OLD_STORY] = {"version": old_story["version"], "data": old_story["data"]}
	if not story_decks.is_empty():
		var deck_data: Dictionary = old_decks["data"].duplicate(true)
		deck_data["decks"] = story_decks
		sections[OLD_DECKS] = {"version": old_decks["version"], "data": deck_data}
	var old_time: int = store.modified_time(OLD_STORY) if old_story["state"] == SaveStore.OK_STATE else store.modified_time(OLD_DECKS)
	if not _write(1, {"saved_at": old_time if old_time > 0 else now.call(), "played_seconds": 0, "sections": sections}):
		return false
	if old_story["state"] == SaveStore.OK_STATE:
		store.rename_file(OLD_STORY, OLD_STORY + BEFORE_SLOTS)
	if not story_decks.is_empty():
		store.copy_file(OLD_DECKS, OLD_DECKS + BEFORE_SLOTS)
		var rest: Dictionary = old_decks["data"].duplicate(true)
		rest["decks"] = versus_decks
		store.write(OLD_DECKS, old_decks["version"], rest)
	return true


# ---- ファイル ----


## スロット number を読む。{"state", ...}（info と同じ形。時間を足す前）。
func _read(number: int) -> Dictionary:
	var raw: Dictionary
	if store == null:
		if not _memory.has(number):
			return {"state": EMPTY}
		raw = {"state": SaveStore.OK_STATE, "version": FORMAT_VERSION, "data": (_memory[number] as Dictionary).duplicate(true)}
	else:
		raw = store.inspect(store_name(number))
	if raw["state"] == SaveStore.MISSING:
		return {"state": EMPTY}
	if raw["state"] == SaveStore.BROKEN:
		return {"state": BROKEN}
	if raw["version"] > FORMAT_VERSION:
		return {"state": NEWER}
	var data := _migrate(raw["version"], raw["data"])
	var sections: Variant = data.get("sections")
	var written_at: Variant = data.get("saved_at")
	var played: Variant = data.get("played_seconds")
	if typeof(sections) != TYPE_DICTIONARY:
		return {"state": BROKEN}
	return {
		"state": READY,
		"sections": sections,
		"saved_at": int(written_at) if typeof(written_at) in [TYPE_INT, TYPE_FLOAT] else 0,
		"played_seconds": maxi(0, int(played)) if typeof(played) in [TYPE_INT, TYPE_FLOAT] else 0,
	}


func _write(number: int, data: Dictionary) -> bool:
	if store == null:
		_memory[number] = data.duplicate(true)
		return true
	return store.write(store_name(number), FORMAT_VERSION, data)


## 古い版の中身を、いまの形に読み替える。いまは版 1 だけ。
static func _migrate(_version: int, data: Dictionary) -> Dictionary:
	return data


func _take_time() -> void:
	var at := Time.get_ticks_msec()
	if counting:
		_played += (at - _clock_from) / 1000.0
	_clock_from = at


## いまのスロットのまとまり 1 つを、save_store.gd と同じ形（read / write）で読み書きするもの。
class Section:
	extends RefCounted
	var _slots: RefCounted
	var _buffered: bool

	func _init(slots: RefCounted, buffered: bool) -> void:
		_slots = slots
		_buffered = buffered

	func read(name: String) -> Dictionary:
		return _slots._read_section(name)

	func write(name: String, version: int, data: Dictionary) -> bool:
		return _slots._write_section(name, version, data, _buffered)

	## いまのスロットを、もう書いたか（始めたか）。
	func is_started() -> bool:
		return _slots.is_started()
