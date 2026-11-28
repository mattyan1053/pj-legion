extends RefCounted
## ストーリー（docs/story.md）: 物語の並びと、物語ごとの進み具合（クリアした話、選んだ部隊）。読み書きは save_store.gd（user://story.json）。
## ノードに依存しない。
##
## - 物語は、軍 1 つと話の列（game/story/ の 1 フォルダ。campaign.gd）。物語のファイル（story.txt）の order の順に並ぶ。物語を選んでから、その物語の話を選ぶ。
## - 話は物語の中で一本道（game/story/<物語>/ の 1 ファイル。episode.gd）。物語の [episodes] の順に並ぶ。話の一覧（episode_list_screen.gd）で、前の話をクリアした話と、クリアした話を選べる。
## - 進み具合（クリア、選んだ部隊、雇える駒）は物語ごと。名前に物語の付かない関数は、いま選んでいる物語（campaign）の進み具合を読む。
## - 書くのは、物語ごとの、クリアした話の id の一覧と、出撃準備で最後に選んだ部隊の id だけ。
##   壊れたファイル・知らない id があっても、起動を止めない（知らない話・物語の記録は残して書き戻す）。
## - 負けても失うものは無い。何度でもやり直せる。

const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")
const DeckText := preload("res://game/deck_text.gd")
const HeroName := preload("res://game/hero_name.gd")
const SaveStore := preload("res://game/save_store.gd")
const Run := preload("res://game/run.gd")
const SceneFlow := preload("res://game/scene_flow.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const Campaign := preload("res://game/campaign.gd")
const Episode := preload("res://game/episode.gd")
const SaveFormat := preload("res://game/save_format.gd")
const TalkScene := preload("res://game/talk_scene.gd")

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
## 会話の場面と、対戦の場面と、話の一覧の場面の名前（scene_flow.gd）。
const TALK := SceneFlow.TALK
const BATTLE := SceneFlow.BATTLE
const EPISODE_LIST := SceneFlow.EPISODES
const SORTIE := SceneFlow.SORTIE

## 最初の物語の id。版 1 の記録（物語が 1 つだったころ）は、この物語の記録として読む。
const MILITARY_ID := &"military"
## 既定の編成で、役割ごとに 1 つ持たせる装備の候補（前から順に、持たせられて、コストが収まる最初の 1 つ。無い役割は持たせない）。
## ストーリー専用の持ち物（ジェットパック、古竜の鱗）を解放したら、盾・ブーツのかわりに持たせる。
## ほかの新しい持ち物は持たせない（どの駒に何を持たせるかは、人が選ぶ。既定の編成は素直な形のまま）。
const DEFAULT_ITEMS := {
	UnitKind.Role.VANGUARD: [Equipment.Id.DRAGON_SCALE, Equipment.Id.IRON_SHIELD],
	UnitKind.Role.RAIDER: [Equipment.Id.JET_PACK, Equipment.Id.SPEED_BOOTS],
}
## 会話の行の、知らせ（話し手の名前の札を金の縁にする。「飛ばす」でも飛ばさない。talk_screen.gd）。名前は notice_name()。
const NOTICE_SIDE := TalkScene.NOTICE_SIDE

## 知らせの行の話し手の名前。
static func notice_name() -> String:
	return Text.t("story.news.speaker")


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
## いま遊んでいる話の流れ（run_now が作ったもの。弱い参照）。話の途中で名乗ったとき、先の場面へ名前を入れ直す。
var _run: WeakRef
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


# ---- 物語 ----

## 読み込んだ物語の並び（最初に使うときに game/story/ から読む）と、読み込みの書き間違い。
static var _campaigns: Array[Campaign] = []
static var _problems: PackedStringArray = []
static var _loaded := false


## 物語の並び（物語のファイルの order の順）。話の無い物語は「準備中」で、選べない。
## 書き間違いのある話は並ばない（読み込みの書き間違いは load_problems() と、エラーの出力）。
static func campaigns() -> Array[Campaign]:
	if not _loaded:
		_loaded = true
		var found: Dictionary = Campaign.load_all()
		_campaigns.assign(found["campaigns"])
		_problems = found["problems"]
		for each: Campaign in _campaigns:
			_problems.append_array(each.problems)
		for problem: String in _problems:
			push_error("ストーリーのデータの書き間違い: " + problem)
	return _campaigns


## 物語と話のファイルの書き間違い（空なら正しい。test_episode_data.gd が見る）。
static func load_problems() -> PackedStringArray:
	campaigns()
	return _problems


## 物語 id（無ければ null）。
static func campaign_by_id(id: StringName) -> Campaign:
	for each: Campaign in campaigns():
		if each.id == id:
			return each
	return null


## 最初の物語（MILITARY の物語）。
static func military() -> Campaign:
	return campaign_by_id(MILITARY_ID)


## 軍 army の物語（並びの最初のもの。無ければ null）。
static func campaign_of_army(army: UnitKind.Army) -> Campaign:
	for each: Campaign in campaigns():
		if each.army == army:
			return each
	return null


## 物語 of_campaign を選ぶ（話の一覧・出撃準備・選んだ部隊・雇える駒は、この物語のものになる）。
## 最後に選んだ物語は記録に書く（セーブのスロットの札に出す。save_slots.gd）。
func choose_campaign(of_campaign: Campaign) -> void:
	campaign = of_campaign
	if _last_campaign != String(of_campaign.id):
		_last_campaign = String(of_campaign.id)
		if not open_all:  # 確かめ用に開いている間は、記録に触らない（次に書くときに、いっしょに書く）
			_save()


## 物語 of_campaign を遊べるか（話が 1 つ以上ある）。話の無い物語は「準備中」。
static func is_ready(of_campaign: Campaign) -> bool:
	return of_campaign.is_ready()


## 話 episode の物語（どの物語にも無ければ null）。
static func campaign_of(episode: Episode) -> Campaign:
	for each: Campaign in campaigns():
		if each.episodes.has(episode):
			return each
	return null


## どの物語の話も、物語の順・話の順に並べたもの。
static func all_episodes() -> Array[Episode]:
	var episodes: Array[Episode] = []
	for each: Campaign in campaigns():
		episodes.append_array(each.episodes)
	return episodes


# ---- 進み具合（いまの物語） ----


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
	# 話の途中で名乗ったとき（会話の「(name)」）: いまの流れの、先の場面の文と札にも入れる。
	var run: Run = _run.get_ref() if _run != null else null
	if run != null:
		rename_run(run, of_campaign.hero, named)
	return named


## 流れ run の場面（会話、話の対戦）に、主人公（既定の名前 default_name）の名前 named を入れ直す。
static func rename_run(run: Run, default_name: String, named: String) -> void:
	for data: Variant in run.all_data():
		if data is StoryBattle:
			if (data as StoryBattle).episode.hero == default_name:
				(data as StoryBattle).hero = named
		elif data is TalkScene:
			rename_talk(data, default_name, named)


## 会話 talk の文と札に、主人公（既定の名前 default_name）の名前 named を入れ直す（書いたままの文から作り直す）。
static func rename_talk(talk: TalkScene, default_name: String, named: String) -> void:
	if talk.hero != default_name or default_name == "":
		return
	for line in talk.lines:
		if line.raw != "":
			line.text = HeroName.fill(line.raw, named)
		if line.hero_line:
			line.name = named
		if line.choice != null:
			for option in line.choice.options:
				option.text = HeroName.fill(option.raw, named)


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


## 話 episode の、その物語の並びの番号（1 から。どの物語にも無ければ 0）。
static func number_of(episode: Episode) -> int:
	var of_campaign := campaign_of(episode)
	return 0 if of_campaign == null else of_campaign.episodes.find(episode) + 1


## 物語 of_campaign の、背景に景色を見せる話（物語選択・セーブデータ選択。title_backdrop.gd の show_story）:
## クリアしたいちばん先の話 last の次の話（last が最後の話ならそれ。last が無ければ最初の話）。
static func scape_episode(of_campaign: Campaign, last: Episode) -> Episode:
	if last == null:
		return of_campaign.episodes[0]
	var at := of_campaign.episodes.find(last)
	return of_campaign.episodes[mini(at + 1, of_campaign.episodes.size() - 1)]


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


# ---- 解放（docs/story.md の「解放」） ----


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


# ---- 流れ ----


## 話 episode を、いまの進み具合で始める流れ（run_of。人の部隊は、出撃準備で選ぶまで、いま使えるもので組んだ既定の編成）。
## 話の物語を、いまの物語にする。初めてクリアする話なら、あとの会話の最後に、増えるものの知らせを出す。
func run_now(episode: Episode) -> Run:
	choose_campaign(campaign_of(episode))
	if open_all and not _reachable(episode.id) and not _opened_runs.has(String(episode.id)):
		_opened_runs.append(String(episode.id))
	var now := unlocked()
	var news: Array[TalkScene.Line] = []
	if not is_cleared(episode.id):
		# 知らせは記録どおりの進み具合から（確かめ用に開いていても、あとの会話の知らせを確かめられる）。
		news = _unlocked_in(campaign, true).news_of(episode)
	var run := run_of(episode, default_deck(now), news, hero_name())
	_run = weakref(run)
	return run


## 話 episode の流れ（run.gd）: 話の場面の列（episode.gd の scenes。[before]・[after] の話は 出撃準備 → 会話（前）→ 対戦 → 会話（後））を順に並べ、終えたら話の一覧。
## クリアの記録は、対戦のある話は対戦に勝ったとき（story_battle.gd の record_win）、対戦の無い話は最後の会話を読み終えたとき（会話に渡す clears）。
## 人の部隊は human_deck（出撃準備で選び直せる）。場面の種類ごとに、流れのどの場面にして何を渡すかは、ここだけで決める。
## 会話（前）は、出撃してから対戦の前に 1 度だけ出す（場面の once。決着の画面の「部隊変更」で出撃準備へ戻って出撃し直しても、もう出さない）。
## 対戦で負けたら、決着の画面から「同じマップで再戦」「部隊変更」（出撃準備へ）か「話の一覧へ」。勝ったら「次へ」で、あとの会話へ。
## あとの会話を読み終えたら「次の話へ」（物語の次の話の流れを始める）か「話の一覧へ」。次の話が無ければ、話の一覧へ。
## システムメニューからは、いつでも「話の一覧へ」（menu_exits）。
## news: この話のクリアで増えるものの知らせ（Unlocked.news_of）。最後の場面が会話なら、その最後に知らせの行で出し、「次の話へ」を選ばせる。
## 最後の場面がカットシーンなら、「次の話へ」はそこで選ばせ、知らせがあるときだけ、知らせだけの会話の場面をあとに足す。
## hero: 遊ぶ人の付けた主人公の名前（空なら既定の名前）。会話・途中の台詞・負けの台詞に差し込む。
static func run_of(episode: Episode, human_deck: Deck, news: Array[TalkScene.Line] = [], hero := "") -> Run:
	var run := Run.new()
	run.exit = EPISODE_LIST
	run.menu_exits = [[EPISODE_LIST, "story.episodes.resume", "menu.to_episodes.confirm"]]
	var battle := StoryBattle.new(episode, human_deck)
	battle.hero = hero
	var fought := false  # 対戦の場面を過ぎたか（会話の背景の盤に、決着したときの駒を立たせる）
	var last_talk: TalkScene = null
	var last_music := &""
	for scene in episode.scenes:
		last_talk = null
		match scene.kind:
			Episode.StoryScene.Kind.SORTIE:
				run.add(SORTIE, {"episode": episode, "battle": battle})  # 出撃準備で、battle の人の部隊を選び直す
			Episode.StoryScene.Kind.BATTLE:
				run.add(BATTLE, battle)
				fought = true
			Episode.StoryScene.Kind.TALK:
				var talk := talk_of(episode, scene.lines, scene.music, hero)
				talk.shape = scene.talk_shape()
				match talk.shape:
					TalkScene.Shape.MAP:
						if episode.has_battle():
							talk.battle = battle  # 背景の盤に、初期位置の駒か、決着したときの駒を立たせる（talk_screen.gd）
							talk.after = fought
					TalkScene.Shape.PLACE:
						# 別の場所の会話: 背景はその場所の景色（兵は立たせない）。
						talk.board = scene.place.make_board()
						talk.look = scene.look
					TalkScene.Shape.CUT:
						# カットシーン: 文の枠も話し手も出さず、背景（景色か、色の幕）の上に文を出す（talk_screen.gd）。
						talk.color = scene.color
						if scene.place != null:
							talk.board = scene.place.make_board()
							talk.look = scene.look
					TalkScene.Shape.BOARD_CUT:
						# 盤のカットシーン: 背景は台本の盤（place か話の盤）で、台本の兵だけが立って動く（talk_screen.gd）。
						talk.cut_board = scene.board_cut
						talk.beats = scene.beats
						talk.look = scene.look if scene.place != null else episode.look
						talk.looks = person_looks(episode)
				run.add(TALK, talk, scene.once)
				last_talk = talk
				last_music = scene.music
	if last_talk != null:
		if not last_talk.shows_speakers() and not news.is_empty():
			# カットシーンで終わる話: 知らせは、文の枠のある場面で出す（カットシーンには枠が無い）。知らせだけの会話の場面を、あとに 1 つ足す。
			# 背景は話の盤（対戦のある話なら、決着したときの兵）。曲は、カットシーンのものを続ける。
			last_talk = talk_of(episode, [], last_music, hero)
			if episode.has_battle():
				last_talk.battle = battle
				last_talk.after = fought
			run.add(TALK, last_talk)
		last_talk.lines.append_array(news)
		last_talk.closes = true
		last_talk.next_episode = episode_after(episode)
		if not episode.has_battle():
			last_talk.clears = episode.id  # 対戦の無い話は、最後の会話を読み終えたらクリア（talk_screen.gd の _end）
	return run


## 話の一覧（と物語選択）の「部隊編成」で始める流れ（run.gd）: 部隊編成（of_campaign のストーリー用）→ 戻り先 back_to。
## 寄り道で取っておいた部隊は、その物語の出撃準備で選ばれる（deck_screen.gd の leave。物語を、いまの物語にしてから始める）。
## back_label は編成の「戻る」の文字の鍵。
static func deck_run(of_campaign: Campaign, back_to: StringName, back_label: String) -> Run:
	var detour := Run.new()
	detour.add(SceneFlow.DECKS, {"rules": of_campaign.rules_id, "back_label": back_label})
	detour.add(back_to)
	return detour


## 話し手の名前 -> 人物の形（unit_looks.gd の PERSONS の名前。[cast] の姿に人物の形があるか、将の姿のある陣営の将）。
## 盤のカットシーンで、話し手と同じ名前の兵を、その人の形で立たせる。
static func person_looks(episode: Episode) -> Dictionary:
	var looks := {}
	for i in mini(episode.speakers.size(), episode.figures.size()):
		var look: StringName = (episode.figures[i] as Dictionary).get("look", &"")
		if look != &"":
			looks[episode.speakers[i]] = look
	return looks


## 物語の並びで episode の次の話（物語の最後なら null）。
static func episode_after(episode: Episode) -> Episode:
	var of_campaign := campaign_of(episode)
	if of_campaign == null:
		return null
	var at := of_campaign.episodes.find(episode)
	return of_campaign.episodes[at + 1] if at >= 0 and at + 1 < of_campaign.episodes.size() else null


## 会話の場面（talk_screen.gd）に渡すもの（talk_scene.gd。型は MAP）: 話 episode の行 rows を、曲 track で。背景は話の盤。
## 主人公の名前 hero（空なら既定の名前）を、文と札に入れる。話の流れ（run_of）が、場面の型と、型ごとの欄を足す。
static func talk_of(episode: Episode, rows: Array[Episode.TalkLine], track := &"", hero := "") -> TalkScene:
	var talk := TalkScene.make(TalkScene.Shape.MAP, episode.title)
	for row in rows:
		# 地の文（話し手が -1）は、名前の無い行（talk_screen.gd が、札を出さずに真ん中へ出す）。
		var line := TalkScene.Line.new(row.side, row.speaker_in(episode.speakers, hero), row.shown_text(hero), row.who)
		# 主人公の名前が話の途中で決まったら、入れ直せるように（rename_talk）: 印のある文は書いたままの文も、主人公の行は印を持つ。
		if row.text.contains(HeroName.MARK):
			line.raw = row.text
		line.hero_line = row.hero != "" and row.speaker_in(episode.speakers) == row.hero
		line.naming = row.asks_name  # この行のあとで、名前を聞く（まだ名乗っていなければ。talk_screen/talk_naming.gd）
		# 選択肢（docs/story.md の「選択肢」）: この行のあとに選ばせるものと、この行を出す条件。
		if row.asks():
			var options: Array[TalkScene.Option] = []
			for option: Dictionary in row.options:
				options.append(TalkScene.Option.new(option["key"], HeroName.fill(option["text"], hero if hero != "" else row.hero), option["text"]))
			line.choice = TalkScene.Choice.new(row.choice, options)
		if row.when_choice != &"":
			line.when = TalkScene.When.new(row.when_choice, row.when_answer, row.when_not)
		talk.lines.append(line)
	talk.board = episode.map.make_board()
	talk.look = episode.look
	talk.track = track
	talk.figures = episode.figures
	talk.hero = episode.hero
	return talk
