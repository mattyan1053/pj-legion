extends "res://tests/base_test.gd"
## 話のデータ（game/episodes/ の 1 ファイル。docs/story.md の「話のデータ」）の書き間違いを、起動する前に弾く。
## 話のデータの定数は、書き間違えると黙って無視されるもの（HOLD_TURNS・WINS・CUES は、無ければ「無い話」になる）が多いので、
## 知らない定数の名前、無い駒・装備、置けないマス、勝ち方の列の矛盾、きっかけの値を、ここでまとめて見る。
## 見方そのものが効くことは、わざと壊した話のデータ（_broken）で確かめる。

const Story := preload("res://game/story.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const BattleCues := preload("res://game/battle_cues.gd")
const StageLook := preload("res://game/stage_look.gd")
const SoundCatalog := preload("res://game/sound_catalog.gd")

## 話のデータに書いてよい定数の名前（preload した道具の名前は除く。_problems が Script の定数を読み飛ばす）。
const REQUIRED := [&"ID", &"TITLE", &"LOOK", &"MAP", &"UNLOCKS", &"ENEMY_ARMY", &"ENEMY", &"DEPLOY", &"SPEAKERS", &"BEFORE", &"AFTER"]
const OPTIONAL := [&"HOLD_TURNS", &"WINS", &"CUES", &"HUMAN_LEADER", &"ENEMY_LEADER", &"MUSIC", &"TALK_MUSIC"]


func test_every_episode_is_well_formed() -> void:
	for episode in Story.EPISODES:
		assert_eq(_problems(episode), [] as Array[String], "%s の話のデータ" % episode.ID)


func test_unlocks_are_new_kinds_and_unlocked_once() -> void:
	var unlocked: Array = Story.STARTING_KINDS.duplicate()
	for episode in Story.EPISODES:
		for kind: UnitKind.Id in episode.UNLOCKS:
			assert_false(unlocked.has(kind), "%s: %s はもう雇える" % [episode.ID, UnitKind.display_name(kind)])
			unlocked.append(kind)


func test_a_full_squad_is_placed_on_every_episode_map() -> void:
	for episode in Story.EPISODES:
		var deck := Deck.new(Story.ARMY, Story.rules_of(Story.STARTING_KINDS))
		for i in Deck.MAX_UNITS:
			deck.add(Story.STARTING_KINDS[i % Story.STARTING_KINDS.size()])
		var setup := StoryBattle.new(episode, deck).make_setup(3)
		setup.ignore_budget = true  # 数だけを見る（予算は出撃の準備と編成の画面が見る）
		var battle := setup.create_battle()
		var placed := [0, 0]
		for unit in battle.units:
			if unit.side != Unit.Side.NEUTRAL:
				placed[unit.side] += 1
		assert_eq(placed, [Deck.MAX_UNITS + 1, episode.ENEMY.size() + 1], "%s: 両軍の全員が盤に置かれる" % episode.ID)


## わざと壊した話のデータを、見方が弾くこと。
func test_broken_episode_data_is_caught() -> void:
	var cases := {
		"知らない定数": "const HOLD_TURN := 10",
		"守り切るのに守り切るの勝ち方が無い": "const HOLD_TURNS := 5\nconst WINS: Array[GameWonEvent.Reason] = [GameWonEvent.Reason.ROUTED]",
		"守り切るの勝ち方なのにターン数が無い": "const WINS: Array[GameWonEvent.Reason] = [GameWonEvent.Reason.TURNS_HELD]",
		"空の勝ち方": "const WINS: Array[GameWonEvent.Reason] = []",
		"知らない曲": "const MUSIC := &\"no_such_track\"",
		"知らない会話の曲": "const TALK_MUSIC := &\"no_such_track\"",
		"きっかけの値": "const CUES := [[&\"king_half\", 2, 0, \"だれの将か\"]]",
		"知らないきっかけ": "const CUES := [[&\"turn_end\", 1, 0, \"なに\"]]",
		"ターン 0": "const CUES := [[&\"turn\", 0, 0, \"はじめ\"]]",
		"守り切るターンの外": "const HOLD_TURNS := 5\nconst WINS: Array[GameWonEvent.Reason] = [GameWonEvent.Reason.TURNS_HELD]\nconst CUES := [[&\"turn\", 6, 0, \"もう遅い\"]]",
	}
	for name: String in cases:
		assert_false(_problems(_broken(cases[name])).is_empty(), "弾けない: %s" % name)
	var swaps := {
		"敵に将": ["[UnitKind.Id.PALADIN, []]", "[UnitKind.Id.KING, []]"],
		"無い駒": ["[UnitKind.Id.PALADIN, []]", "[99, []]"],
		"無い装備": ["[UnitKind.Id.PALADIN, []]", "[UnitKind.Id.PALADIN, [99]]"],
		"置けないマス": ["const DEPLOY := [[], []]", "const DEPLOY := [[], [Vector2i(0, 0), Vector2i(-1, 3)]]"],
		"話し手": ["[0, \"いくぞ\"]", "[2, \"いくぞ\"]"],
		"見た目": ["StageLook.STONE_WALLS", "&\"swamp\""],
		"将を解放": ["const UNLOCKS: Array[UnitKind.Id] = []", "const UNLOCKS: Array[UnitKind.Id] = [UnitKind.Id.KING]"],
	}
	for name: String in swaps:
		var source := BASE.replace(swaps[name][0], swaps[name][1])
		assert_ne(source, BASE, name)
		assert_false(_problems(_broken("", source)).is_empty(), "弾けない: %s" % name)
	assert_eq(_problems(_broken("")), [] as Array[String], "見本そのものは正しい")


# ---- 見方 ----


## 話 episode のデータの書き間違い（空なら正しい）。
func _problems(episode: Script) -> Array[String]:
	var found: Array[String] = []
	var constants := episode.get_script_constant_map()
	for name: StringName in constants:
		if constants[name] is Script:
			continue  # preload した道具（マップ、見た目、きっかけ）
		if not REQUIRED.has(name) and not OPTIONAL.has(name):
			found.append("知らない定数 %s（書き間違いは黙って無視される）" % name)
	for name: StringName in REQUIRED:
		if not constants.has(name):
			found.append("%s が無い" % name)
	if not found.is_empty():
		return found
	if String(episode.ID) == "" or episode.TITLE == "":
		found.append("id か見出しが空")
	if not StageLook.THEMES.has(episode.LOOK):
		found.append("知らない見た目 %s" % episode.LOOK)
	for name: StringName in [&"MUSIC", &"TALK_MUSIC"]:
		if constants.has(name) and not SoundCatalog.has_music(constants[name]):
			found.append("知らない曲 %s（%s）" % [constants[name], name])
	var map: HandMap = episode.MAP.map()
	if not map.problems().is_empty():
		found.append("マップを盤にできない: %s" % [map.problems()])
		return found
	for kind: Variant in episode.UNLOCKS:
		if not _is_kind(kind) or kind == UnitKind.Id.KING:
			found.append("解放できない駒 %s" % [kind])
	if not UnitKind.Army.values().has(episode.ENEMY_ARMY):
		found.append("知らない軍 %s" % [episode.ENEMY_ARMY])
	if episode.ENEMY.is_empty():
		found.append("敵の部隊が空")
	for row: Array in episode.ENEMY:
		if row.size() != 2 or not _is_kind(row[0]) or row[0] == UnitKind.Id.KING:
			found.append("敵の駒の行が読めない: %s" % [row])
			continue
		for item: Variant in row[1]:
			if typeof(item) != TYPE_INT or not Equipment.Id.values().has(item):
				found.append("無い装備 %s" % [item])
	found.append_array(_deploy_problems(episode, map.make_board()))
	found.append_array(_win_problems(episode, constants))
	found.append_array(_talk_problems(episode, constants))
	return found


func _is_kind(kind: Variant) -> bool:
	return typeof(kind) == TYPE_INT and UnitKind.Id.values().has(kind)


func _deploy_problems(episode: Script, board: Board) -> Array[String]:
	var found: Array[String] = []
	if episode.DEPLOY.size() != 2:
		return ["DEPLOY は [プレイヤー1, プレイヤー2] の 2 つ"]
	var seen := {}
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		for cell: Variant in episode.DEPLOY[side]:
			if typeof(cell) != TYPE_VECTOR2I or not board.is_walkable(cell) or board.object_at(cell) != MapObject.Type.NONE or board.hq_cells.has(cell):
				found.append("初期位置 %s に置けない" % [cell])
			elif seen.has(cell):
				found.append("初期位置 %s が重なっている" % [cell])
			seen[cell] = true
	var enemy_cells: Array = episode.DEPLOY[Unit.Side.PLAYER2]
	if not enemy_cells.is_empty() and enemy_cells.size() < episode.ENEMY.size():
		found.append("敵の初期位置が足りない")
	var human_cells: Array = episode.DEPLOY[Unit.Side.PLAYER1]
	if not human_cells.is_empty() and human_cells.size() < Deck.MAX_UNITS:
		found.append("人の初期位置が、部隊の数の上限より少ない")
	return found


func _win_problems(episode: Script, constants: Dictionary) -> Array[String]:
	var found: Array[String] = []
	var holds := constants.has(&"HOLD_TURNS")
	if holds and (typeof(episode.HOLD_TURNS) != TYPE_INT or episode.HOLD_TURNS < 1):
		found.append("HOLD_TURNS は 1 以上")
	if constants.has(&"WINS"):
		var wins: Array = episode.WINS
		if wins.is_empty():
			found.append("勝ち方が空（人が勝てない）")
		for reason: Variant in wins:
			if typeof(reason) != TYPE_INT or not GameWonEvent.Reason.values().has(reason):
				found.append("知らない勝ち方 %s" % [reason])
		# story_battle.gd は WINS で勝ち方を置き換える。守り切るのに TURNS_HELD が無いと、守り切っても勝てない。
		if holds != wins.has(GameWonEvent.Reason.TURNS_HELD):
			found.append("HOLD_TURNS と、WINS の TURNS_HELD は、両方あるか両方無いか")
	return found


func _talk_problems(episode: Script, constants: Dictionary) -> Array[String]:
	var found: Array[String] = []
	if episode.SPEAKERS.size() != 2 or episode.SPEAKERS.has(""):
		found.append("話し手は 2 人（人の軍、敵の軍）")
	for rows: Array in [episode.BEFORE, episode.AFTER]:
		if rows.is_empty():
			found.append("会話が空")
		for row: Array in rows:
			if row.size() != 2 or not row[0] in [0, 1] or String(row[1]) == "":
				found.append("会話の行が読めない: %s" % [row])
	if not constants.has(&"CUES"):
		return found
	for cue: Array in episode.CUES:
		if cue.size() != 4 or not BattleCues.KINDS.has(cue[0]) or not cue[2] in [0, 1] or String(cue[3]) == "":
			found.append("途中の会話の行が読めない: %s" % [cue])
			continue
		match cue[0]:
			BattleCues.TURN:
				if cue[1] < 1:
					found.append("ターンは 1 から: %s" % [cue])
				elif constants.has(&"HOLD_TURNS") and cue[1] > episode.HOLD_TURNS:
					found.append("守り切るターンの外（出ない）: %s" % [cue])
			BattleCues.KING_HALF, BattleCues.FALLEN:
				if not cue[1] in [0, 1]:
					found.append("陣営は 0 か 1: %s" % [cue])
	return found


# ---- わざと壊した話のデータ ----

## 正しい話のデータの見本（尾根の小道のマップ）。
const BASE := """extends RefCounted
const RidgePath := preload("res://rules/maps/ridge_path.gd")
const StageLook := preload("res://game/stage_look.gd")
const ID := &"probe"
const TITLE := "見本"
const LOOK := StageLook.STONE_WALLS
const MAP := RidgePath
const UNLOCKS: Array[UnitKind.Id] = []
const ENEMY_ARMY := UnitKind.Army.FANTASY
const ENEMY := [[UnitKind.Id.PALADIN, []]]
const DEPLOY := [[], []]
const SPEAKERS := ["隊長", "敵将"]
const BEFORE := [[0, "いくぞ"]]
const AFTER := [[1, "退け"]]
"""


func _broken(extra: String, base := BASE) -> Script:
	var script := GDScript.new()
	script.source_code = base + extra + "\n"
	assert_eq(script.reload(), OK, "見本のスクリプトが読めない: %s" % extra)
	return script
