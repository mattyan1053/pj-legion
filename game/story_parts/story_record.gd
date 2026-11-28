extends "res://game/story_parts/story_catalog.gd"
## ストーリー（game/story.gd）の、記録と進み具合: 物語ごとの、クリアした話・選んだ部隊・選択肢の答えと、主人公の名前。読み書きは save_store.gd（user://story.json）。
## ノードに依存しない。継ぐ順は story_catalog.gd の頭。
##
## - 進み具合（クリア、選んだ部隊、雇える駒）は物語ごと。名前に物語の付かない関数は、いま選んでいる物語（campaign）の進み具合を読む。
## - 書くのは、物語ごとの、クリアした話の id の一覧と、出撃準備で最後に選んだ部隊の id と、選択肢の答え。ほかに、最後に選んだ物語と主人公の名前。
##   壊れたファイル・知らない id があっても、起動を止めない（知らない話・物語の記録は残して書き戻す）。
## - 負けても失うものは無い。何度でもやり直せる。

const SaveStore := preload("res://game/save_store.gd")
const SaveFormat := preload("res://game/save_format.gd")

## クリアした話が増えた。
signal changed

## save_store.gd で置くまとまりの名前と、中身の形の版（欄を足したら上げる。決まりは save_format.gd）。
## 版 1 は物語が 1 つだったころの形（{"cleared", "squad"}）。読むときは MILITARY の物語の記録として引き継ぐ（_migrate）。
const STORE_NAME := "story"

## 版 3 で、物語ごとの記録に「answers」（選択肢で選んだ答え）を足した。版 4 で、「heroes」（主人公に付けた名前）を足した。
const FORMAT_VERSION := 4

## 記録の中身の、いまの版が知っている欄（ほかの欄は、新しい版の exe が書いたものとして残す）。
const KNOWN_KEYS := ["campaigns", "campaign", "heroes"]
const RECORD_KEYS := ["cleared", "squad", "answers"]

## 取っておく先（null なら書かない。検査・自動の対戦・スクリーンショットでは null）。
var store: RefCounted

## いま選んでいる物語（物語を選ぶ画面で選ぶ。記録には書かない）。
var campaign: Campaign = military()

## 物語の id（String）-> {"cleared": [話の id（String）, …], "squad": 部隊の id（空なら既定の編成）, "kept": 知らない欄}。知らない物語の記録も残す。
var _records := {}

## 読んだ記録の版と、記録の知らない欄（新しい exe が書いた欄。書き戻すときに残す。save_format.gd）。
var _read_version := FORMAT_VERSION
var _kept := {}

## 主人公に付けた名前: 既定の名前（物語のファイルの hero）-> 付けた名前。同じ主人公の物語（本編と番外）で 1 つ。
## 鍵があれば、名前を決めたことがある（既定のままでも入れる。物語を始めるときの名前の窓を、もう出さない）。
var _heroes := {}

## 最後に選んだ物語の id（空なら、まだ選んでいない）。記録に書く。
var _last_campaign := ""

## 確かめ用に、全部の話と解放を開いているか（docs/story.md の「確かめ用の解放」。F5）。その起動のあいだだけで、記録には書かない。
## 開いている間は、どの話も遊べ、どの物語でも全部の解放を使える。開いている間に勝った話のクリアは、記録に書かずに覚えておき、戻すと捨てる。
var open_all := false:
	set(value):
		open_all = value
		_open_cleared.clear()
		changed.emit()
## 確かめ用に開いている間に勝った話の id（記録には書かない）。
var _open_cleared: Array[String] = []

## 確かめ用に開いている間に始めた、記録どおりではまだ遊べない話の id（その起動のあいだ、勝っても記録に書かない）。
var _opened_runs: Array[String] = []

## 出撃準備で最後に選んだ部隊（いまの物語の。取っておいた部隊の id。空なら既定の編成）。次に起動しても選ばれている。
var squad_id: String:
	get:
		return _record(campaign)["squad"]


## 記録を読む（いまの記録は捨てる）。
func load_saved() -> void:
	_records.clear()
	_heroes.clear()
	_last_campaign = ""
	_read_version = FORMAT_VERSION
	_kept = {}
	if store == null:
		return
	var saved: Dictionary = store.read(STORE_NAME)
	if not saved.is_empty():
		load_data(saved["data"], saved["version"])


## 中身（ファイルの data。版 version）から記録を作る。形の違うところは読み飛ばす。古い版は _migrate で読み替える。
## 知らない欄（新しい版の exe が書いたもの）は、書き戻すときのために残す。
func load_data(source: Dictionary, version := FORMAT_VERSION) -> void:
	var data := _migrate(version, source)
	_records.clear()
	_read_version = version
	_kept = SaveFormat.unknown(data, KNOWN_KEYS, version, FORMAT_VERSION)
	# 確かめ用に開いている間のクリアと、開いて始めた話は、そのとき遊んでいたスロットのもの。ほかのスロットへ持ち越さない
	# （持ち越すと、ほかのスロットで記録どおりに遊べるようになった話に勝っても、記録に書かない）。
	_open_cleared.clear()
	_opened_runs.clear()
	var last: Variant = data.get("campaign")
	_last_campaign = String(last) if typeof(last) in [TYPE_STRING, TYPE_STRING_NAME] else ""
	_heroes.clear()
	var saved_heroes: Variant = data.get("heroes")
	if typeof(saved_heroes) == TYPE_DICTIONARY:
		for hero: Variant in saved_heroes:
			var named: Variant = saved_heroes[hero]
			# 使えない名前（長すぎる、画面の字に無い文字。手で書き換えたファイル）は、読み飛ばす（既定の名前に戻る）。
			if typeof(hero) in [TYPE_STRING, TYPE_STRING_NAME] and typeof(named) in [TYPE_STRING, TYPE_STRING_NAME] and HeroName.is_valid(String(named)):
				_heroes[String(hero)] = String(named)
	var saved_campaigns: Variant = data.get("campaigns")
	if typeof(saved_campaigns) != TYPE_DICTIONARY:
		saved_campaigns = {}
	for id: Variant in saved_campaigns:
		if typeof(id) in [TYPE_STRING, TYPE_STRING_NAME] and String(id) != "" and typeof(saved_campaigns[id]) == TYPE_DICTIONARY:
			_records[String(id)] = _read_record(saved_campaigns[id], version)
	_fill_earlier_clears()


## 話は物語の中で一本道なので、クリアした話より前の話は、どれもクリアしたものとして読む。
## 物語の頭に話が足された（チュートリアル）とき、前の版の記録で先へ進んでいた人が、足された話のぶん解放と本編を失わないため。
func _fill_earlier_clears() -> void:
	for each: Campaign in campaigns():
		var id := String(each.id)
		if not _records.has(id):
			continue
		var cleared: Array = _records[id]["cleared"]
		var last := -1
		for i: int in each.episodes.size():
			if cleared.has(String(each.episodes[i].id)):
				last = i
		for i: int in last:
			if not cleared.has(String(each.episodes[i].id)):
				cleared.append(String(each.episodes[i].id))


## 版 version の中身を、いまの形に読み替える。
## 版 1（物語が 1 つだったころの {"cleared", "squad"}）は、MILITARY の物語の記録にする。
static func _migrate(version: int, data: Dictionary) -> Dictionary:
	if version <= 1:
		return {"campaigns": {String(MILITARY_ID): data}}
	return data


static func _read_record(data: Dictionary, version: int) -> Dictionary:
	var cleared: Array[String] = []
	var ids: Variant = data.get("cleared")
	if typeof(ids) == TYPE_ARRAY:
		for id: Variant in ids:
			if typeof(id) in [TYPE_STRING, TYPE_STRING_NAME] and String(id) != "" and not cleared.has(String(id)):
				cleared.append(String(id))
	var squad: Variant = data.get("squad")
	var answers := {}
	var saved_answers: Variant = data.get("answers")
	if typeof(saved_answers) == TYPE_DICTIONARY:
		for name: Variant in saved_answers:
			var key: Variant = saved_answers[name]
			if typeof(name) in [TYPE_STRING, TYPE_STRING_NAME] and typeof(key) in [TYPE_STRING, TYPE_STRING_NAME] and String(name) != "" and String(key) != "":
				answers[String(name)] = String(key)
	return {"cleared": cleared, "squad": String(squad) if typeof(squad) in [TYPE_STRING, TYPE_STRING_NAME] else "", "answers": answers,
			"kept": SaveFormat.unknown(data, RECORD_KEYS, version, FORMAT_VERSION)}


## ファイルに書く中身: {"campaigns": {物語の id: {"cleared": [話の id, …], "squad": 部隊の id（既定の編成なら書かない）,
## "answers": {選択肢の名前: 選んだ答えの鍵}（選んでいなければ書かない）}}}。
## クリアも部隊も無い物語は書かない。
func to_data() -> Dictionary:
	var written_campaigns := {}
	for id: String in _records:
		var record: Dictionary = _records[id]
		var written := {"cleared": (record["cleared"] as Array).duplicate()}
		if record["squad"] != "":
			written["squad"] = record["squad"]
		if not (record.get("answers", {}) as Dictionary).is_empty():
			written["answers"] = (record["answers"] as Dictionary).duplicate()
		var kept: Dictionary = record.get("kept", {})
		if not (written["cleared"] as Array).is_empty() or written.has("squad") or written.has("answers") or not kept.is_empty():
			written_campaigns[id] = SaveFormat.with_unknown(written, kept)
	var written_data := {"campaigns": written_campaigns}
	if _last_campaign != "":
		written_data["campaign"] = _last_campaign
	if not _heroes.is_empty():
		written_data["heroes"] = _heroes.duplicate()
	return SaveFormat.with_unknown(written_data, _kept)


## 物語 of_campaign の記録（無ければ空の記録を作る）。
func _record(of_campaign: Campaign) -> Dictionary:
	var id := String(of_campaign.id)
	if not _records.has(id):
		_records[id] = {"cleared": [] as Array[String], "squad": "", "answers": {}, "kept": {}}
	return _records[id]


func _cleared_in(of_campaign: Campaign) -> Array:
	return _record(of_campaign)["cleared"]


## 物語 of_campaign を選ぶ（話の一覧・出撃準備・選んだ部隊・雇える駒は、この物語のものになる）。
## 最後に選んだ物語は記録に書く（セーブのスロットの札に出す。save_slots.gd）。
func choose_campaign(of_campaign: Campaign) -> void:
	campaign = of_campaign
	if _last_campaign != String(of_campaign.id):
		_last_campaign = String(of_campaign.id)
		if not open_all:  # 確かめ用に開いている間は、記録に触らない（次に書くときに、いっしょに書く）
			_save()


## 話 id をクリアしたか（いまの物語で）。
func is_cleared(id: StringName) -> bool:
	return _cleared_in(campaign).has(String(id)) or _open_cleared.has(String(id))


## 話 id をクリアしたと書く（いまの物語に。もう書いてあれば何もしない）。確かめ用に開いている間は、記録に書かずに覚えるだけ。
## 確かめ用に開いて始めた、記録どおりではまだ遊べない話（_opened_runs）は、途中で戻してから勝っても記録に書かない
## （書くと、一本道の読み方で前の話が全部クリアになる）。
func clear(id: StringName) -> void:
	if is_cleared(id):
		return
	if open_all:
		_open_cleared.append(String(id))
		changed.emit()
		return
	if _opened_runs.has(String(id)):
		return
	_cleared_in(campaign).append(String(id))
	_save()
	changed.emit()


## 出撃準備で選んだ部隊 id（空なら既定の編成）を、いまの物語に覚える（変わったときだけ書く）。
func choose_squad(id: String) -> void:
	if id == squad_id:
		return
	_record(campaign)["squad"] = id
	_save()


## 物語 of_campaign（省けば、いまの物語）の主人公の名前（遊ぶ人が付けた名前。付けていなければ既定の名前。主人公のいない物語は空）。
func hero_name(of_campaign: Campaign = null) -> String:
	var at: Campaign = campaign if of_campaign == null else of_campaign
	return String(_heroes.get(at.hero, at.hero)) if at.hero != "" else ""


## 物語 of_campaign の主人公の名前を、決めたことがあるか（無ければ、物語を始めるときに名前の窓を出す。主人公のいない物語は真）。
func is_hero_named(of_campaign: Campaign) -> bool:
	return of_campaign.hero == "" or _heroes.has(of_campaign.hero)


## 物語 of_campaign の主人公に名前 typed を付ける（使えない文字と長すぎる分は落とす。空なら既定の名前）。付いた名前を返す。
func name_hero(of_campaign: Campaign, typed: String) -> String:
	if of_campaign.hero == "":
		return ""
	var named := HeroName.clean(typed)
	if named == "":
		named = of_campaign.hero
	if _heroes.get(of_campaign.hero, "") != named:
		_heroes[of_campaign.hero] = named
		_save()
		changed.emit()
	_renamed(of_campaign.hero, named)
	return named


## 主人公（既定の名前 default_name）に名前 named が付いた。流れ（story.gd）が、いまの流れの先の場面へ入れ直す。
func _renamed(_default_name: String, _named: String) -> void:
	pass


## 選択肢 choice で選んだ答えの鍵（いまの物語で。まだ選んでいなければ空）。あとの話の「(if 名前 = 鍵)」の行が読む（docs/story.md の「選択肢」）。
func answer_of(choice: StringName) -> String:
	return _record(campaign)["answers"].get(String(choice), "")


## 選択肢 choice で答え key を選んだと覚える（いまの物語に。選び直せば上書き）。
## 確かめ用に開いている間は、記録のファイルに触らない（次に書くときに、いっしょに書く）。
func choose_answer(choice: StringName, key: StringName) -> void:
	if answer_of(choice) == String(key):
		return
	_record(campaign)["answers"][String(choice)] = String(key)
	if not open_all:
		_save()


func _save() -> void:
	if store != null:
		store.write(STORE_NAME, written_version(), to_data())


## 書くときの版（新しい版の記録を読んでいたら、その版のまま。save_format.gd）。
func written_version() -> int:
	return SaveFormat.written_version(_read_version, FORMAT_VERSION)


## 記録の中身 data（ファイルの data）の要約（セーブのスロットの札）: {"campaign": 最後に選んだ物語（無ければ、クリアのある最初の物語。どちらも無ければ null）,
## "cleared": その物語でクリアした話の数, "total": その物語の話の数, "last": その物語でクリアしたいちばん先の話（無ければ null）}。
static func summary_of(data: Dictionary, version := FORMAT_VERSION) -> Dictionary:
	var reader := new()
	reader.load_data(data, version)
	var chosen: Campaign = campaign_by_id(StringName(reader._last_campaign)) if reader._last_campaign != "" else null
	if chosen == null:
		for each: Campaign in campaigns():
			if reader.cleared_count(each) > 0:
				chosen = each
				break
	if chosen == null:
		return {"campaign": null, "cleared": 0, "total": 0, "last": null}
	var last: Episode = null
	for each: Episode in chosen.episodes:
		if reader._cleared_in(chosen).has(String(each.id)):
			last = each
	return {"campaign": chosen, "cleared": reader.cleared_count(chosen), "total": chosen.episodes.size(), "last": last}


## 物語 of_campaign（省けば、いまの物語）の話のうち、クリアした話の数。
func cleared_count(of_campaign: Campaign = null) -> int:
	var at: Campaign = campaign if of_campaign == null else of_campaign
	var cleared := _cleared_in(at)
	return at.episodes.filter(func(episode: Episode) -> bool: return cleared.has(String(episode.id))).size()


## 遊べる物語を、どれも全部クリアしたか（タイトルの「ストーリー（クリア済み）」）。
func all_cleared() -> bool:
	for each: Campaign in campaigns():
		if is_ready(each) and cleared_count(each) < each.episodes.size():
			return false
	return true


## 話 id が、記録どおりの進み具合で遊べるか（確かめ用に開いているかに依らない）。いまの物語に無い話は、遊べるものとして扱う。
func _reachable(id: StringName) -> bool:
	for index: int in campaign.episodes.size():
		if campaign.episodes[index].id == id:
			return index == 0 or _cleared_in(campaign).has(String(campaign.episodes[index - 1].id))
	return true


## 話 episode を遊べるか（いまの物語の話で）: 並びの最初の話か、1 つ前の話をクリアしている（一本道）。クリアした話は、いつでも遊び直せる。
func is_available(episode: Episode) -> bool:
	var index: int = campaign.episodes.find(episode)
	if open_all and index >= 0:
		return true
	return index == 0 or (index > 0 and is_cleared(campaign.episodes[index - 1].id))


## 物語 of_campaign で、まだクリアしていない最初の話（全部クリアしていたら最後の話）。背景に景色を見せる話。
func scape_episode_in(of_campaign: Campaign) -> Episode:
	var cleared := _cleared_in(of_campaign)  # いま選んでいる物語でなくても、その物語の記録を見る
	for episode: Episode in of_campaign.episodes:
		if not cleared.has(String(episode.id)):
			return episode
	return of_campaign.episodes[-1]


## 次に遊ぶ話（いまの物語で）: まだクリアしていない最初の話。全部クリアしていたら最初の話。
func next_episode() -> Episode:
	for episode: Episode in campaign.episodes:
		if not is_cleared(episode.id):
			return episode
	return campaign.episodes[0]
