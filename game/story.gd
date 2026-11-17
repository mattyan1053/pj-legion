extends RefCounted
## ストーリー（docs/story.md）: 物語の並びと、物語ごとの進み具合（クリアした話、選んだ部隊）。読み書きは save_store.gd（user://story.json）。
## ノードに依存しない。
##
## - 物語は、軍 1 つと話の列（game/story/campaigns/ の 1 ファイル。campaign.gd）。game/story/campaigns.txt の順に並ぶ。物語を選んでから、その物語の話を選ぶ。
## - 話は物語の中で一本道（game/story/episodes/ の 1 ファイル。episode.gd）。物語の [episodes] の順に並ぶ。話の一覧（episode_list_screen.gd）で、前の話をクリアした話と、クリアした話を選べる。
## - 進み具合（クリア、選んだ部隊、雇える駒）は物語ごと。名前に物語の付かない関数は、いま選んでいる物語（campaign）の進み具合を読む。
## - 書くのは、物語ごとの、クリアした話の id の一覧と、出撃準備で最後に選んだ部隊の id だけ。
##   壊れたファイル・知らない id があっても、起動を止めない（知らない話・物語の記録は残して書き戻す）。
## - 負けても失うものは無い。何度でもやり直せる。

const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")
const DeckText := preload("res://game/deck_text.gd")
const SaveStore := preload("res://game/save_store.gd")
const Run := preload("res://game/run.gd")
const SceneFlow := preload("res://game/scene_flow.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const Campaign := preload("res://game/campaign.gd")
const Episode := preload("res://game/episode.gd")

## クリアした話が増えた。
signal changed

## save_store.gd で置くまとまりの名前と、中身の形の版。
## 版 1 は物語が 1 つだったころの形（{"cleared", "squad"}）。読むときは MILITARY の物語の記録として引き継ぐ。
const STORE_NAME := "story"
const FORMAT_VERSION := 2
## 会話の場面と、対戦の場面と、話の一覧の場面の名前（scene_flow.gd）。
const TALK := SceneFlow.TALK
const BATTLE := SceneFlow.BATTLE
const EPISODE_LIST := SceneFlow.EPISODES
const SORTIE := SceneFlow.SORTIE

## 最初の物語の id。版 1 の記録（物語が 1 つだったころ）は、この物語の記録として読む。
const MILITARY_ID := &"military"
## 既定の編成で、役割ごとに 1 つ持たせる装備の候補（前から順に、持たせられて、コストが収まる最初の 1 つ。無い役割は持たせない）。
## ストーリー専用の持ち物（ジェットパック、古竜の鱗）を解放したら、盾・ブーツのかわりに持たせる。遠眼鏡は後衛に。
const DEFAULT_ITEMS := {
	UnitKind.Role.VANGUARD: [Equipment.Id.DRAGON_SCALE, Equipment.Id.IRON_SHIELD],
	UnitKind.Role.REARGUARD: [Equipment.Id.LONG_SCOPE],
	UnitKind.Role.RAIDER: [Equipment.Id.JET_PACK, Equipment.Id.SPEED_BOOTS],
}
## 会話の行の、知らせ（話し手の名前の札を灰色にする。「飛ばす」でも飛ばさない。talk_screen.gd）。名前は notice_name()。
const NOTICE_SIDE := 2

## 知らせの行の話し手の名前。
static func notice_name() -> String:
	return Text.t("story.news.speaker")


## 取っておく先（null なら書かない。検査・自動の対戦・スクリーンショットでは null）。
var store: RefCounted
## いま選んでいる物語（物語を選ぶ画面で選ぶ。記録には書かない）。
var campaign: Campaign = military()
## 物語の id（String）-> {"cleared": [話の id（String）, …], "squad": 部隊の id（空なら既定の編成）}。知らない物語の記録も残す。
var _records := {}
## 出撃準備で最後に選んだ部隊（いまの物語の。取っておいた部隊の id。空なら既定の編成）。次に起動しても選ばれている。
var squad_id: String:
	get:
		return _record(campaign)["squad"]


## 記録を読む（いまの記録は捨てる）。
func load_saved() -> void:
	_records.clear()
	if store == null:
		return
	var saved: Dictionary = store.read(STORE_NAME)
	if not saved.is_empty():
		load_data(saved["data"])


## 中身（ファイルの data）から記録を作る。形の違うところは読み飛ばす。
## 版 1 の形（{"cleared", "squad"}。物語が 1 つだったころ）は、MILITARY の物語の記録として読む。
func load_data(data: Dictionary) -> void:
	_records.clear()
	var saved_campaigns: Variant = data.get("campaigns")
	if typeof(saved_campaigns) != TYPE_DICTIONARY:
		_records[String(MILITARY_ID)] = _read_record(data)
		_fill_earlier_clears()
		return
	for id: Variant in saved_campaigns:
		if typeof(id) in [TYPE_STRING, TYPE_STRING_NAME] and String(id) != "" and typeof(saved_campaigns[id]) == TYPE_DICTIONARY:
			_records[String(id)] = _read_record(saved_campaigns[id])
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


static func _read_record(data: Dictionary) -> Dictionary:
	var cleared: Array[String] = []
	var ids: Variant = data.get("cleared")
	if typeof(ids) == TYPE_ARRAY:
		for id: Variant in ids:
			if typeof(id) in [TYPE_STRING, TYPE_STRING_NAME] and String(id) != "" and not cleared.has(String(id)):
				cleared.append(String(id))
	var squad: Variant = data.get("squad")
	return {"cleared": cleared, "squad": String(squad) if typeof(squad) in [TYPE_STRING, TYPE_STRING_NAME] else ""}


## ファイルに書く中身: {"campaigns": {物語の id: {"cleared": [話の id, …], "squad": 部隊の id（既定の編成なら書かない）}}}。
## クリアも部隊も無い物語は書かない。
func to_data() -> Dictionary:
	var written_campaigns := {}
	for id: String in _records:
		var record: Dictionary = _records[id]
		var written := {"cleared": (record["cleared"] as Array).duplicate()}
		if record["squad"] != "":
			written["squad"] = record["squad"]
		if not (written["cleared"] as Array).is_empty() or written.has("squad"):
			written_campaigns[id] = written
	return {"campaigns": written_campaigns}


## 物語 of_campaign の記録（無ければ空の記録を作る）。
func _record(of_campaign: Campaign) -> Dictionary:
	var id := String(of_campaign.id)
	if not _records.has(id):
		_records[id] = {"cleared": [] as Array[String], "squad": ""}
	return _records[id]


func _cleared_in(of_campaign: Campaign) -> Array:
	return _record(of_campaign)["cleared"]


# ---- 物語 ----

## 読み込んだ物語の並び（最初に使うときに game/story/ から読む）と、読み込みの書き間違い。
static var _campaigns: Array[Campaign] = []
static var _problems: PackedStringArray = []
static var _loaded := false


## 物語の並び（game/story/campaigns.txt の順）。話の無い物語は「準備中」で、選べない。
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


## 物語 of_campaign を選ぶ（話の一覧・出撃準備・選んだ部隊・雇える駒は、この物語のものになる）。
func choose_campaign(of_campaign: Campaign) -> void:
	campaign = of_campaign


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
	return _cleared_in(campaign).has(String(id))


## 話 id をクリアしたと書く（いまの物語に。もう書いてあれば何もしない）。
func clear(id: StringName) -> void:
	if is_cleared(id):
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


func _save() -> void:
	if store != null:
		store.write(STORE_NAME, FORMAT_VERSION, to_data())


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


## 話 episode を遊べるか（いまの物語の話で）: 並びの最初の話か、1 つ前の話をクリアしている（一本道）。クリアした話は、いつでも遊び直せる。
func is_available(episode: Episode) -> bool:
	var index: int = campaign.episodes.find(episode)
	return index == 0 or (index > 0 and is_cleared(campaign.episodes[index - 1].id))


## 話 episode の、その物語の並びの番号（1 から。どの物語にも無ければ 0）。
static func number_of(episode: Episode) -> int:
	var of_campaign := campaign_of(episode)
	return 0 if of_campaign == null else of_campaign.episodes.find(episode) + 1


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

	func _init(of_campaign: Campaign) -> void:
		campaign = of_campaign
		kinds.assign(of_campaign.starting_kinds)
		items.assign(of_campaign.starting_items)
		budget = of_campaign.starting_budget

	## 話 episode のクリアで増えるものを足す。
	func add(episode: Episode) -> void:
		for kind: UnitKind.Id in episode.unlock_kinds:
			if not kinds.has(kind):
				kinds.append(kind)
		for item: Equipment.Id in episode.unlock_items:
			if not items.has(item):
				items.append(item)
		budget += episode.budget_up

	## 話 episode のクリアで、これより新しく増えるものの知らせ（増えるものが無ければ空）。
	## 1 つが {"text": 文} で、駒なら "kind"、持ち物なら "item" も持つ（会話の場面が、文の左に駒・持ち物のアイコンを出す）。
	func news_of(episode: Episode) -> Array[Dictionary]:
		var lines: Array[Dictionary] = []
		for kind: UnitKind.Id in episode.unlock_kinds:
			if not kinds.has(kind):
				lines.append({"text": Text.t("story.news.unit", {"unit": Names.kind(kind)}), "kind": kind})
		for item: Equipment.Id in episode.unlock_items:
			if not items.has(item):
				lines.append({"text": Text.t("story.news.item", {"item": Names.item(item), "effect": DeckText.equipment_effect(item)}), "item": item})
		var more := episode.budget_up
		if more > 0:
			lines.append({"text": Text.t("story.news.budget", {"budget": budget + more})})
		return lines


## いまの物語で、いま使えるもの（クリアした話から求める）。
func unlocked() -> Unlocked:
	return _unlocked_in(campaign)


## いま雇える駒の種類（いまの物語で）。
func unlocked_kinds() -> Array[UnitKind.Id]:
	return unlocked().kinds


func _unlocked_in(of_campaign: Campaign) -> Unlocked:
	var result := Unlocked.new(of_campaign)
	var cleared := _cleared_in(of_campaign)
	for episode: Episode in of_campaign.episodes:
		if cleared.has(String(episode.id)):
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
	return DeckRules.new(given.campaign.rules_id, Deck.MAX_UNITS, {army: roster}, {army: given.budget}, given.items, offered_items(given.campaign))


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
	var now := unlocked()
	var news: Array[Dictionary] = []
	if not is_cleared(episode.id):
		news = now.news_of(episode)
	return run_of(episode, default_deck(now), news)


## 話 episode の流れ（run.gd）: 会話（前）→ 出撃準備 → 対戦 → 会話（後）→ 話の一覧。人の部隊は human_deck（出撃準備で選び直せる）。
## 対戦で負けたら、決着の画面から「同じ盤面でもう一度」「部隊を選び直す」（出撃準備へ）か「タイトルへ」。勝ったら「次へ」で、あとの会話へ。
## news: この話のクリアで増えるものの知らせ（Unlocked.news_of）。あとの会話の最後に、知らせの行で出す。
static func run_of(episode: Episode, human_deck: Deck, news: Array[Dictionary] = []) -> Run:
	var run := Run.new()
	run.exit = EPISODE_LIST
	run.add(TALK, talk_of(episode, episode.before))
	var battle := StoryBattle.new(episode, human_deck)
	run.add(SORTIE, {"episode": episode, "battle": battle})  # 出撃準備で、battle の人の部隊を選び直す
	run.add(BATTLE, battle)
	var after := talk_of(episode, episode.after)
	for news_line: Dictionary in news:
		var line := {"side": NOTICE_SIDE, "name": notice_name()}
		line.merge(news_line)
		after["lines"].append(line)
	run.add(TALK, after)
	return run


## 会話の場面（talk_screen.gd）に渡すもの: {"title": 見出し, "lines": [{"side": 0 か 1, "name": 話し手, "text": 文}, …],
## "board": 背景の盤（話のマップ）, "look": 盤の見た目, "music": 曲（話のファイルの talk_music。空なら場面の表の曲）}。
static func talk_of(episode: Episode, rows: Array) -> Dictionary:
	var lines: Array[Dictionary] = []
	for row: Array in rows:
		lines.append({"side": row[0], "name": episode.speakers[row[0]], "text": row[1]})
	return {"title": episode.title, "lines": lines, "board": episode.map.make_board(), "look": episode.look,
			"music": episode.talk_music}
