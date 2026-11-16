extends RefCounted
## ストーリー（docs/story.md）: 話の並びと、進み具合（クリアした話）。読み書きは save_store.gd（user://story.json）。
## ノードに依存しない。
##
## - 話は一本道。EPISODES の順に並ぶ。タイトルの「ストーリー」は、まだクリアしていない最初の話を始める（全部クリアしたら最初の話）。
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
## 会話の場面と、対戦の場面の名前（scene_flow.gd）。
const TALK := &"talk"
const BATTLE := &"battle"

## 話の並び（一本道。game/episodes/ の 1 ファイルが 1 話）。
const EPISODES: Array[Script] = [
	preload("res://game/episodes/ridge_path.gd"),
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


## タイトルの「ストーリー」で始める話: まだクリアしていない最初の話。全部クリアしていたら最初の話。
func next_episode() -> Script:
	for episode in EPISODES:
		if not is_cleared(episode.ID):
			return episode
	return EPISODES[0]


## 話 episode の流れ（run.gd）: 会話（前）→ 対戦 → 会話（後）→ タイトル。
## 対戦で負けたら、決着の画面から「同じ盤面でもう一度」か「タイトルへ」。勝ったら「次へ」で、あとの会話へ。
static func run_of(episode: Script) -> Run:
	var run := Run.new()
	run.add(TALK, talk_of(episode, episode.BEFORE))
	run.add(BATTLE, StoryBattle.new(episode))
	run.add(TALK, talk_of(episode, episode.AFTER))
	return run


## 会話の場面（talk_screen.gd）に渡すもの: {"title": 見出し, "lines": [{"side": 0 か 1, "name": 話し手, "text": 文}, …],
## "board": 背景の盤（話のマップ）, "look": 盤の見た目}。
static func talk_of(episode: Script, rows: Array) -> Dictionary:
	var lines: Array[Dictionary] = []
	for row: Array in rows:
		lines.append({"side": row[0], "name": episode.SPEAKERS[row[0]], "text": row[1]})
	return {"title": episode.TITLE, "lines": lines, "board": episode.MAP.map().make_board(), "look": episode.LOOK}
