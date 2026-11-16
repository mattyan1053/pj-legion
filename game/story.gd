extends RefCounted
## ストーリー（docs/story.md）: 話の並びと、進み具合（クリアした話）。読み書きは save_store.gd（user://story.json）。
## ノードに依存しない。
##
## - 話は一本道。EPISODES の順に並ぶ。話の一覧（episode_list_screen.gd）で、前の話をクリアした話と、クリアした話を選べる。
## - 書くのは、クリアした話の id の一覧だけ。壊れたファイル・知らない id があっても、起動を止めない（知らない id は残して書き戻す）。
## - 負けても失うものは無い。何度でもやり直せる。

const SaveStore := preload("res://game/save_store.gd")
const Run := preload("res://game/run.gd")
const StoryBattle := preload("res://game/story_battle.gd")

## クリアした話が増えた。
signal changed

## save_store.gd で置くまとまりの名前と、中身の形の版。
const STORE_NAME := "story"
const FORMAT_VERSION := 1
## 会話の場面と、対戦の場面と、話の一覧の場面の名前（scene_flow.gd）。
const TALK := &"talk"
const BATTLE := &"battle"
const EPISODE_LIST := &"episodes"

## ストーリーの編成の決まりの名前（取っておく部隊に書く）。対戦の決まり（DeckRules.VERSUS）と分ける。
const RULES_ID := &"story"
## ストーリーで人が使う軍（仮。Issue #49 の ★2）。
const ARMY := UnitKind.Army.MILITARY
## 最初から雇える駒の種類。ほかは、話をクリアすると増える（話のデータの UNLOCKS）。
const STARTING_KINDS: Array[UnitKind.Id] = [UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SNIPER, UnitKind.Id.MEDIC]
## 会話の行の、知らせ（話し手の名前の札を灰色にする。「飛ばす」でも飛ばさない。talk_screen.gd）。
const NOTICE_SIDE := 2
const NOTICE_NAME := "知らせ"

## 話の並び（一本道。game/episodes/ の 1 ファイルが 1 話）。
const EPISODES: Array[Script] = [
	preload("res://game/episodes/ridge_path.gd"),
	preload("res://game/episodes/ridge_ambush.gd"),
]

## 取っておく先（null なら書かない。検査・自動の対戦・スクリーンショットでは null）。
var store: RefCounted
var _cleared: Array[String] = []


## クリアした話を読む（いまの記録は捨てる）。
func load_saved() -> void:
	_cleared.clear()
	if store == null:
		return
	var saved: Dictionary = store.read(STORE_NAME)
	if not saved.is_empty():
		load_data(saved["data"])


## 中身（ファイルの data）から記録を作る。形の違うところは読み飛ばす。
func load_data(data: Dictionary) -> void:
	_cleared.clear()
	var ids: Variant = data.get("cleared")
	if typeof(ids) != TYPE_ARRAY:
		return
	for id: Variant in ids:
		if typeof(id) in [TYPE_STRING, TYPE_STRING_NAME] and String(id) != "" and not _cleared.has(String(id)):
			_cleared.append(String(id))


## ファイルに書く中身。
func to_data() -> Dictionary:
	return {"cleared": _cleared.duplicate()}


func is_cleared(id: StringName) -> bool:
	return _cleared.has(String(id))


## 話 id をクリアしたと書く（もう書いてあれば何もしない）。
func clear(id: StringName) -> void:
	if is_cleared(id):
		return
	_cleared.append(String(id))
	if store != null:
		store.write(STORE_NAME, FORMAT_VERSION, to_data())
	changed.emit()


## 並びのうち、クリアした話の数。
func cleared_count() -> int:
	return EPISODES.filter(func(episode: Script) -> bool: return is_cleared(episode.ID)).size()


func all_cleared() -> bool:
	return cleared_count() == EPISODES.size()


## 話 episode を遊べるか: 並びの最初の話か、1 つ前の話をクリアしている（一本道）。クリアした話は、いつでも遊び直せる。
func is_available(episode: Script) -> bool:
	var index := EPISODES.find(episode)
	return index == 0 or (index > 0 and is_cleared(EPISODES[index - 1].ID))


## 話 episode の、並びの番号（1 から。並びに無ければ 0）。
static func number_of(episode: Script) -> int:
	return EPISODES.find(episode) + 1


## 次に遊ぶ話: まだクリアしていない最初の話。全部クリアしていたら最初の話。
func next_episode() -> Script:
	for episode in EPISODES:
		if not is_cleared(episode.ID):
			return episode
	return EPISODES[0]


# ---- 駒の解放（docs/story.md の「駒の解放」） ----


## いま雇える駒の種類: 最初から雇える駒と、クリアした話が解放する駒（記録には書かず、その場で求める）。
func unlocked_kinds() -> Array[UnitKind.Id]:
	var kinds := STARTING_KINDS.duplicate()
	for episode in EPISODES:
		if is_cleared(episode.ID):
			_add_kinds(kinds, episode.UNLOCKS)
	return kinds


## いまの進み具合の、ストーリーの編成の決まり。
func deck_rules() -> DeckRules:
	return rules_of(unlocked_kinds())


## 話 episode を初めて遊ぶときに雇える駒の種類: 最初から雇える駒と、並びでその話より前の話が解放する駒。
## 話の敵の強さは、この駒で組んだ既定の編成で測る（tools/cpu_matches.gd の --episode）。
static func kinds_before(episode: Script) -> Array[UnitKind.Id]:
	var kinds := STARTING_KINDS.duplicate()
	for earlier in EPISODES:
		if earlier == episode:
			break
		_add_kinds(kinds, earlier.UNLOCKS)
	return kinds


## 雇える駒の種類 kinds の、ストーリーの編成の決まり。予算と数の上限は対戦と同じ（Issue #49 の設計の表の 9）。
## 解放した駒は、軍が違っても ARMY のロスターに入る。並びは役割の順（前衛・後衛・奇襲・回復）。
static func rules_of(kinds: Array[UnitKind.Id]) -> DeckRules:
	var roster := kinds.duplicate()
	roster.sort_custom(func(a: UnitKind.Id, b: UnitKind.Id) -> bool:
		return UnitKind.role(a) < UnitKind.role(b) or (UnitKind.role(a) == UnitKind.role(b) and a < b))
	return DeckRules.new(RULES_ID, "ストーリー", Deck.MAX_UNITS, {ARMY: roster}, {ARMY: DeckRules.versus().budget(ARMY)})


## 雇える駒の種類 kinds の、ストーリーの既定の編成（CPU の編成の組み方。CpuDeck）。
static func default_deck(kinds: Array[UnitKind.Id]) -> Deck:
	return CpuDeck.build(ARMY, rules_of(kinds))


## 話 episode の対戦（人は、その話を初めて遊ぶときの既定の編成）。敵の強さを測る道具が使う。
static func first_battle(episode: Script) -> StoryBattle:
	return StoryBattle.new(episode, default_deck(kinds_before(episode)))


static func _add_kinds(kinds: Array[UnitKind.Id], more: Array) -> void:
	for kind: UnitKind.Id in more:
		if not kinds.has(kind):
			kinds.append(kind)


# ---- 流れ ----


## 話 episode を、いまの進み具合で始める流れ（run_of。人は、いま雇える駒で組んだ既定の編成）。
func run_now(episode: Script) -> Run:
	var newly: Array[UnitKind.Id] = []
	if not is_cleared(episode.ID):
		var kinds := unlocked_kinds()
		for kind: UnitKind.Id in episode.UNLOCKS:
			if not kinds.has(kind):
				newly.append(kind)
	return run_of(episode, default_deck(unlocked_kinds()), newly)


## 話 episode の流れ（run.gd）: 会話（前）→ 対戦 → 会話（後）→ 話の一覧。人の部隊は human_deck。
## 対戦で負けたら、決着の画面から「同じ盤面でもう一度」か「タイトルへ」。勝ったら「次へ」で、あとの会話へ。
## unlocking: この話のクリアで新しく雇えるようになる駒。あとの会話の最後に、知らせの行で出す。
static func run_of(episode: Script, human_deck: Deck, unlocking: Array[UnitKind.Id] = []) -> Run:
	var run := Run.new()
	run.exit = EPISODE_LIST
	run.add(TALK, talk_of(episode, episode.BEFORE))
	run.add(BATTLE, StoryBattle.new(episode, human_deck))
	var after := talk_of(episode, episode.AFTER)
	for kind in unlocking:
		after["lines"].append({"side": NOTICE_SIDE, "name": NOTICE_NAME,
				"text": "新しい駒「%s」を雇えるようになった。" % UnitKind.display_name(kind)})
	run.add(TALK, after)
	return run


## 会話の場面（talk_screen.gd）に渡すもの: {"title": 見出し, "lines": [{"side": 0 か 1, "name": 話し手, "text": 文}, …],
## "board": 背景の盤（話のマップ）, "look": 盤の見た目}。
static func talk_of(episode: Script, rows: Array) -> Dictionary:
	var lines: Array[Dictionary] = []
	for row: Array in rows:
		lines.append({"side": row[0], "name": episode.SPEAKERS[row[0]], "text": row[1]})
	return {"title": episode.TITLE, "lines": lines, "board": episode.MAP.map().make_board(), "look": episode.LOOK}
