extends RefCounted
## ストーリー（docs/story.md）: 物語の並びと、物語ごとの進み具合（クリアした話、選んだ部隊）。読み書きは save_store.gd（user://story.json）。
## ノードに依存しない。
##
## - 物語は、軍 1 つと話の列（game/campaigns/ の 1 ファイル）。CAMPAIGNS の順に並ぶ。物語を選んでから、その物語の話を選ぶ。
## - 話は物語の中で一本道。物語の EPISODES の順に並ぶ。話の一覧（episode_list_screen.gd）で、前の話をクリアした話と、クリアした話を選べる。
## - 進み具合（クリア、選んだ部隊、雇える駒）は物語ごと。名前に物語の付かない関数は、いま選んでいる物語（campaign）の進み具合を読む。
## - 書くのは、物語ごとの、クリアした話の id の一覧と、出撃の準備で最後に選んだ部隊の id だけ。
##   壊れたファイル・知らない id があっても、起動を止めない（知らない話・物語の記録は残して書き戻す）。
## - 負けても失うものは無い。何度でもやり直せる。

const SaveStore := preload("res://game/save_store.gd")
const Run := preload("res://game/run.gd")
const SceneFlow := preload("res://game/scene_flow.gd")
const StoryBattle := preload("res://game/story_battle.gd")

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

## 物語の並び（game/campaigns/ の 1 ファイルが 1 物語）。話の無い物語は「準備中」で、選べない。
const MILITARY := preload("res://game/campaigns/military.gd")
const CAMPAIGNS: Array[Script] = [
	MILITARY,
	preload("res://game/campaigns/fantasy.gd"),
]
## MILITARY の物語の、編成の決まりの名前と軍（部隊の編成の画面の「ストーリー用」は、いまこの物語の決まり）。
const RULES_ID := MILITARY.RULES_ID
const ARMY := MILITARY.ARMY
## 既定の編成で、役割ごとに 1 つ持たせる装備（無い役割は持たせない）。
const DEFAULT_ITEMS := {
	UnitKind.Role.VANGUARD: Equipment.Id.IRON_SHIELD,
	UnitKind.Role.RAIDER: Equipment.Id.SPEED_BOOTS,
}
## 会話の行の、知らせ（話し手の名前の札を灰色にする。「飛ばす」でも飛ばさない。talk_screen.gd）。
const NOTICE_SIDE := 2
const NOTICE_NAME := "知らせ"

## 取っておく先（null なら書かない。検査・自動の対戦・スクリーンショットでは null）。
var store: RefCounted
## いま選んでいる物語（物語を選ぶ画面で選ぶ。記録には書かない）。
var campaign: Script = MILITARY
## 物語の id（String）-> {"cleared": [話の id（String）, …], "squad": 部隊の id（空なら既定の編成）}。知らない物語の記録も残す。
var _records := {}
## 出撃の準備で最後に選んだ部隊（いまの物語の。取っておいた部隊の id。空なら既定の編成）。次に起動しても選ばれている。
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
	var campaigns: Variant = data.get("campaigns")
	if typeof(campaigns) != TYPE_DICTIONARY:
		_records[String(MILITARY.ID)] = _read_record(data)
		return
	for id: Variant in campaigns:
		if typeof(id) in [TYPE_STRING, TYPE_STRING_NAME] and String(id) != "" and typeof(campaigns[id]) == TYPE_DICTIONARY:
			_records[String(id)] = _read_record(campaigns[id])


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
	var campaigns := {}
	for id: String in _records:
		var record: Dictionary = _records[id]
		var written := {"cleared": (record["cleared"] as Array).duplicate()}
		if record["squad"] != "":
			written["squad"] = record["squad"]
		if not (written["cleared"] as Array).is_empty() or written.has("squad"):
			campaigns[id] = written
	return {"campaigns": campaigns}


## 物語 of_campaign の記録（無ければ空の記録を作る）。
func _record(of_campaign: Script) -> Dictionary:
	var id := String(of_campaign.ID)
	if not _records.has(id):
		_records[id] = {"cleared": [] as Array[String], "squad": ""}
	return _records[id]


func _cleared_in(of_campaign: Script) -> Array:
	return _record(of_campaign)["cleared"]


# ---- 物語 ----


## 物語 of_campaign を選ぶ（話の一覧・出撃の準備・選んだ部隊・雇える駒は、この物語のものになる）。
func choose_campaign(of_campaign: Script) -> void:
	campaign = of_campaign


## 物語 of_campaign を遊べるか（話が 1 つ以上ある）。話の無い物語は「準備中」。
static func is_ready(of_campaign: Script) -> bool:
	return not of_campaign.EPISODES.is_empty()


## 話 episode の物語（どの物語にも無ければ null）。
static func campaign_of(episode: Script) -> Script:
	for each in CAMPAIGNS:
		if each.EPISODES.has(episode):
			return each
	return null


## どの物語の話も、物語の順・話の順に並べたもの。
static func all_episodes() -> Array[Script]:
	var episodes: Array[Script] = []
	for each in CAMPAIGNS:
		episodes.append_array(each.EPISODES)
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


## 出撃の準備で選んだ部隊 id（空なら既定の編成）を、いまの物語に覚える（変わったときだけ書く）。
func choose_squad(id: String) -> void:
	if id == squad_id:
		return
	_record(campaign)["squad"] = id
	_save()


func _save() -> void:
	if store != null:
		store.write(STORE_NAME, FORMAT_VERSION, to_data())


## 物語 of_campaign（省けば、いまの物語）の話のうち、クリアした話の数。
func cleared_count(of_campaign: Script = null) -> int:
	var at: Script = campaign if of_campaign == null else of_campaign
	var cleared := _cleared_in(at)
	return at.EPISODES.filter(func(episode: Script) -> bool: return cleared.has(String(episode.ID))).size()


## 遊べる物語を、どれも全部クリアしたか（タイトルの「ストーリー（クリア済み）」）。
func all_cleared() -> bool:
	for each in CAMPAIGNS:
		if is_ready(each) and cleared_count(each) < each.EPISODES.size():
			return false
	return true


## 話 episode を遊べるか（いまの物語の話で）: 並びの最初の話か、1 つ前の話をクリアしている（一本道）。クリアした話は、いつでも遊び直せる。
func is_available(episode: Script) -> bool:
	var index: int = campaign.EPISODES.find(episode)
	return index == 0 or (index > 0 and is_cleared(campaign.EPISODES[index - 1].ID))


## 話 episode の、その物語の並びの番号（1 から。どの物語にも無ければ 0）。
static func number_of(episode: Script) -> int:
	var of_campaign := campaign_of(episode)
	return 0 if of_campaign == null else of_campaign.EPISODES.find(episode) + 1


## 次に遊ぶ話（いまの物語で）: まだクリアしていない最初の話。全部クリアしていたら最初の話。
func next_episode() -> Script:
	for episode: Script in campaign.EPISODES:
		if not is_cleared(episode.ID):
			return episode
	return campaign.EPISODES[0]


# ---- 駒の解放（docs/story.md の「駒の解放」） ----


## いま雇える駒の種類（いまの物語で）: 最初から雇える駒と、クリアした話が解放する駒（記録には書かず、その場で求める）。
func unlocked_kinds() -> Array[UnitKind.Id]:
	return _unlocked_in(campaign)


func _unlocked_in(of_campaign: Script) -> Array[UnitKind.Id]:
	var kinds: Array[UnitKind.Id] = []
	kinds.assign(of_campaign.STARTING_KINDS)
	var cleared := _cleared_in(of_campaign)
	for episode: Script in of_campaign.EPISODES:
		if cleared.has(String(episode.ID)):
			_add_kinds(kinds, episode.UNLOCKS)
	return kinds


## いまの物語の、いまの進み具合の、編成の決まり。
func deck_rules() -> DeckRules:
	return rules_of(unlocked_kinds(), campaign)


## 決まりの名前 rules_id の物語の、いまの進み具合の編成の決まり（どの物語の名前でもなければ null）。
## 取っておいた部隊を読むときに使う（app_context.gd）。
func rules_by_id(rules_id: StringName) -> DeckRules:
	for each in CAMPAIGNS:
		if each.RULES_ID == rules_id:
			return rules_of(_unlocked_in(each), each)
	return null


## 話 episode を初めて遊ぶときに雇える駒の種類: その物語の最初から雇える駒と、並びでその話より前の話が解放する駒。
## 話の敵の強さは、この駒で組んだ既定の編成で測る（tools/cpu_matches.gd の --episode）。
static func kinds_before(episode: Script) -> Array[UnitKind.Id]:
	var of_campaign := campaign_of(episode)
	var kinds: Array[UnitKind.Id] = []
	kinds.assign(of_campaign.STARTING_KINDS)
	for earlier: Script in of_campaign.EPISODES:
		if earlier == episode:
			break
		_add_kinds(kinds, earlier.UNLOCKS)
	return kinds


## 物語 of_campaign（省けば MILITARY）で、雇える駒の種類が kinds のときの編成の決まり。
## 予算と数の上限は対戦と同じ（Issue #49 の設計の表の 9）。並びは役割の順（前衛・後衛・奇襲・回復）。
static func rules_of(kinds: Array[UnitKind.Id], of_campaign: Script = MILITARY) -> DeckRules:
	var roster := kinds.duplicate()
	roster.sort_custom(func(a: UnitKind.Id, b: UnitKind.Id) -> bool:
		return UnitKind.role(a) < UnitKind.role(b) or (UnitKind.role(a) == UnitKind.role(b) and a < b))
	var army: UnitKind.Army = of_campaign.ARMY
	return DeckRules.new(of_campaign.RULES_ID, "ストーリー", Deck.MAX_UNITS, {army: roster}, {army: DeckRules.versus().budget(army)})


## 物語 of_campaign（省けば MILITARY）で、雇える駒の種類が kinds のときの既定の編成。初めて遊ぶ人が出撃の準備で見て納得できる、素直な形にする:
## 1. 雇える駒を、役割の順（前衛・後衛・奇襲・回復）に 1 体ずつ、数の上限まで繰り返して雇う（予算に収まるかぎり。まんべんなく）
## 2. 余った予算で、前衛にアイアンシールド、奇襲にスピードブーツを、1 体に 1 つまで持たせる
## 並びは役割の順（同じ種類はまとめる）。並びの順に初期位置へ置かれるので、前衛が前に出る。
static func default_deck(kinds: Array[UnitKind.Id], of_campaign: Script = MILITARY) -> Deck:
	var rules := rules_of(kinds, of_campaign)
	var deck := Deck.new(of_campaign.ARMY, rules)
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
	for entry in deck.entries:
		var item := DEFAULT_ITEMS.get(UnitKind.role(entry.kind), -1) as int
		if item != -1 and deck.total_cost() + Equipment.cost(item as Equipment.Id) <= deck.budget():
			entry.equip(item as Equipment.Id)
	return deck


## 話 episode の対戦（人は、その話を初めて遊ぶときの既定の編成）。敵の強さを測る道具が使う。
static func first_battle(episode: Script) -> StoryBattle:
	return StoryBattle.new(episode, default_deck(kinds_before(episode), campaign_of(episode)))


static func _add_kinds(kinds: Array[UnitKind.Id], more: Array) -> void:
	for kind: UnitKind.Id in more:
		if not kinds.has(kind):
			kinds.append(kind)


# ---- 流れ ----


## 話 episode を、いまの進み具合で始める流れ（run_of。人の部隊は、出撃の準備で選ぶまで、いま雇える駒で組んだ既定の編成）。
## 話の物語を、いまの物語にする。
func run_now(episode: Script) -> Run:
	choose_campaign(campaign_of(episode))
	var newly: Array[UnitKind.Id] = []
	if not is_cleared(episode.ID):
		var kinds := unlocked_kinds()
		for kind: UnitKind.Id in episode.UNLOCKS:
			if not kinds.has(kind):
				newly.append(kind)
	return run_of(episode, default_deck(unlocked_kinds(), campaign), newly)


## 話 episode の流れ（run.gd）: 会話（前）→ 出撃の準備 → 対戦 → 会話（後）→ 話の一覧。人の部隊は human_deck（出撃の準備で選び直せる）。
## 対戦で負けたら、決着の画面から「同じ盤面でもう一度」「部隊を選び直す」（出撃の準備へ）か「タイトルへ」。勝ったら「次へ」で、あとの会話へ。
## unlocking: この話のクリアで新しく雇えるようになる駒。あとの会話の最後に、知らせの行で出す。
static func run_of(episode: Script, human_deck: Deck, unlocking: Array[UnitKind.Id] = []) -> Run:
	var run := Run.new()
	run.exit = EPISODE_LIST
	run.add(TALK, talk_of(episode, episode.BEFORE))
	var battle := StoryBattle.new(episode, human_deck)
	run.add(SORTIE, {"episode": episode, "battle": battle})  # 出撃の準備で、battle の人の部隊を選び直す
	run.add(BATTLE, battle)
	var after := talk_of(episode, episode.AFTER)
	for kind in unlocking:
		after["lines"].append({"side": NOTICE_SIDE, "name": NOTICE_NAME, "kind": kind,
				"text": "新しい駒「%s」を雇えるようになった。" % UnitKind.display_name(kind)})
	run.add(TALK, after)
	return run


## 会話の場面（talk_screen.gd）に渡すもの: {"title": 見出し, "lines": [{"side": 0 か 1, "name": 話し手, "text": 文}, …],
## "board": 背景の盤（話のマップ）, "look": 盤の見た目, "music": 曲（話のデータの TALK_MUSIC。空なら場面の表の曲）}。
static func talk_of(episode: Script, rows: Array) -> Dictionary:
	var lines: Array[Dictionary] = []
	for row: Array in rows:
		lines.append({"side": row[0], "name": episode.SPEAKERS[row[0]], "text": row[1]})
	return {"title": episode.TITLE, "lines": lines, "board": episode.MAP.map().make_board(), "look": episode.LOOK,
			"music": StoryBattle.talk_music_of(episode)}
