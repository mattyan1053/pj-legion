extends "res://tests/base_test.gd"
## 対戦のログ（game/battle_log.gd。docs/battle-book.md）。

const Names := preload("res://game/names.gd")
const BattleLog := preload("res://game/battle_log.gd")
const Maps := preload("res://tests/support/maps.gd")
const CpuGame := preload("res://tests/support/cpu_game.gd")

const EVENTS_DIR := "res://rules/events"
const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2


func _event_scripts() -> Array[Script]:
	var scripts: Array[Script] = []
	for file in DirAccess.get_files_at(EVENTS_DIR):
		if file.ends_with(".gd"):
			var script: Script = load(EVENTS_DIR.path_join(file))
			if not script.is_abstract():
				scripts.append(script)
	return scripts


## 行の文（見出しを除く。続きの行も含める）。
func _lines(book: BattleLog) -> Array[String]:
	var lines: Array[String] = []
	for entry in book.entries:
		if not entry.header:
			lines.append(entry.full_text())
	return lines


func _apply(battle: Battle, book: BattleLog, action: BattleAction) -> void:
	var result := battle.apply(action)
	assert_true(result.accepted, "行動が断られた: %s" % action.get_script().resource_path)
	book.feed_all(result.events)


func test_every_event_has_a_reading() -> void:
	var readers := BattleLog.readers()
	var methods := {}
	for method in (BattleLog as GDScript).get_script_method_list():
		methods[method["name"]] = true
	var events := _event_scripts()
	assert_true(events.size() >= 12, "イベントのスクリプトを見つけられていない")
	for script in events:
		assert_true(readers.has(script), "ログに読み方が無い: %s" % script.resource_path)
		if readers.has(script):
			assert_true(methods.has(String(readers[script])), "メソッドが無い: %s" % readers[script])
	assert_eq(readers.size(), events.size(), "イベントでないものが載っている")


func test_starts_with_the_current_phase_as_a_header() -> void:
	var battle := Maps.battle(["......"])
	var book := BattleLog.new(battle, ["プレイヤー1（青）", "CPU（赤）"] as Array[String])
	assert_eq(book.entries.size(), 1)
	assert_true(book.entries[0].header)
	assert_eq(book.entries[0].text, "ターン 1　プレイヤー1（青）の番")
	assert_eq(book.entries[0].side, P1)


## 始めからゲージがたまっている陣営は、見出しのすぐ下にそう書く。たまっていなければ書かない。
func test_a_gauge_that_starts_charged_is_noted() -> void:
	var setup := MatchSetup.versus_human(BoardGenerator.Stage.PLAIN, 1, MatchSetup.default_deck(UnitKind.Army.MILITARY), MatchSetup.default_deck(UnitKind.Army.FANTASY))
	var battle := setup.create_battle()
	battle.ult_gauge[P1] = 600
	var book := BattleLog.new(battle)
	assert_eq(_lines(book), ["%sの必殺技のゲージは 60%% から" % Names.side_word(P1)] as Array[String])
	assert_eq(book.entries[1].side, P1)
	battle.ult_gauge[P1] = 0
	assert_eq(_lines(BattleLog.new(battle)), [] as Array[String], "0 から始まるなら書かない")


func test_unit_names_have_the_side_and_the_evolution() -> void:
	var battle := Maps.battle(["......"])
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(5, 0))
	var book := BattleLog.new(battle)
	assert_eq(book.unit_name(paladin.id), "青のパラディン")
	assert_eq(book.unit_name(sniper.id), "赤のスナイパー")
	sniper.evolution = Evolution.Id.MARKSMAN
	book.feed(UnitEvolvedEvent.new(sniper))
	assert_eq(book.unit_name(sniper.id), "赤のマークスマン")
	assert_eq(_lines(book)[-1], "赤のスナイパーがマークスマンに進化した")


func test_move_and_wait_make_one_line() -> void:
	var battle := Maps.battle(["......"])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var book := BattleLog.new(battle)
	_apply(battle, book, MoveAction.new(sniper.id, Vector2i(2, 0)))
	_apply(battle, book, WaitAction.new(sniper.id))
	assert_eq(_lines(book), ["青のスナイパーが (0, 0) → (2, 0) へ移動して待機"] as Array[String])
	assert_eq(book.entries[-1].cell, Vector2i(2, 0))
	assert_eq(book.entries[-1].unit_ids, [sniper.id] as Array[int])


func test_wait_without_moving() -> void:
	var battle := Maps.battle(["......"])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var book := BattleLog.new(battle)
	_apply(battle, book, WaitAction.new(sniper.id))
	assert_eq(_lines(book), ["青のスナイパーは待機"] as Array[String])


func test_cruise_and_portal_are_noted_on_the_move() -> void:
	var battle := Maps.battle(["1....1"])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 0))
	var book := BattleLog.new(battle)
	# (1, 0) → (0, 0) のポータル → (5, 0) → (4, 0)
	var result := battle.apply(MoveAction.new(commando.id, Vector2i(4, 0), true))
	assert_true(result.accepted)
	var warped := false
	for event in result.events:
		warped = warped or event is UnitWarpedEvent
	assert_true(warped, "ポータルを通っていない")
	book.feed_all(result.events)
	assert_eq(_lines(book), ["青のコマンドーが (1, 0) → (4, 0) へ移動（巡航・ポータル経由）"] as Array[String])


func test_undone_move_is_removed() -> void:
	var battle := Maps.battle(["......"])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var book := BattleLog.new(battle)
	book.take_changes()
	_apply(battle, book, MoveAction.new(sniper.id, Vector2i(2, 0)))
	_apply(battle, book, UndoMoveAction.new(sniper.id))
	assert_eq(_lines(book), [] as Array[String])
	assert_eq(book.take_changes(), 1, "消した行から先を作り直す")


func test_attack_shows_damage_and_remaining_hp() -> void:
	var battle := Maps.battle(["..F..."])
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(1, 0))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(2, 0))
	sniper.hp = 30
	var book := BattleLog.new(battle)
	_apply(battle, book, AttackAction.new(paladin.id, sniper.id))
	var line := _lines(book)[-1]
	assert_true(line.begins_with("青のパラディンが赤のスナイパーを攻撃: "), line)
	assert_true(line.contains("残り HP %d" % sniper.hp), line)
	assert_true(line.contains("森で軽減"), line)
	assert_eq(_lines(book).size(), 1, "経験値と行動済みは行にしない")
	assert_eq(book.entries[-1].side, P1)
	assert_eq(book.entries[-1].cell, Vector2i(2, 0), "攻撃された駒のマス")


func test_defeat_is_written_on_the_attack_line() -> void:
	var battle := Maps.battle(["......"])
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(1, 0))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(2, 0))
	sniper.hp = 1
	var book := BattleLog.new(battle)
	_apply(battle, book, AttackAction.new(paladin.id, sniper.id))
	var lines := _lines(book)
	assert_true(lines[0].ends_with("倒した"), lines[0])
	for line in lines:
		assert_false(line.contains("倒れた"), "倒れたことを 2 度書かない: %s" % line)


func test_barrier_is_noted() -> void:
	var battle := Maps.battle(["......"])
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(1, 0))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(2, 0))
	Statuses.add(sniper, Status.Type.BARRIER, 2)
	var book := BattleLog.new(battle)
	_apply(battle, book, AttackAction.new(paladin.id, sniper.id))
	assert_eq(_lines(book)[0], "青のパラディンが赤のスナイパーを攻撃: バリアで防がれた")


func test_skill_damage_is_grouped_under_the_skill() -> void:
	var battle := Maps.battle([
		"........",
		"........",
		"........",
	])
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(1, 1))
	var a := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(3, 1))
	var b := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(3, 2))
	b.hp = 1
	var book := BattleLog.new(battle)
	_apply(battle, book, UseSkillAction.new(sorcerer.id, Vector2i(3, 1)))
	var entry: BattleLog.Entry = book.entries[1]
	assert_eq(entry.text, "青のソーサラーが「%s」を使った（(3, 1)）" % Names.skill(Skills.by_id(Skill.Id.FIREBALL)))
	assert_eq(entry.details.size(), 2, entry.full_text())
	assert_true(entry.details[0].begins_with("赤のスナイパーに "), entry.details[0])
	assert_true(entry.details[1].begins_with("赤のコマンドーに ") and entry.details[1].contains("倒れた"), entry.details[1])
	assert_true(entry.unit_ids.has(a.id) and entry.unit_ids.has(b.id))


func test_ult_statuses_are_one_detail_line() -> void:
	var battle := Maps.battle(["......"])
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0))
	var book := BattleLog.new(battle)
	book.feed(UltUsedEvent.new(P1, Ult.Id.ALL_OUT_ASSAULT))
	for unit in battle.units:
		book.feed(Statuses.add(unit, Status.Type.ASSAULT, 2))
	var entry: BattleLog.Entry = book.entries[-1]
	assert_true(entry.text.begins_with("青が必殺技「"), entry.text)
	assert_eq(entry.details, ["突撃（2 ターン）: 青のシールドトルーパー、青のスナイパー"] as Array[String])


func test_phase_start_makes_a_header_and_heals_are_lines() -> void:
	var battle := Maps.battle(["S....."])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(0, 0))
	sniper.hp = 5
	var book := BattleLog.new(battle)
	_apply(battle, book, EndPhaseAction.new())
	assert_true(book.entries[-2].header, "プレイヤー2 のフェーズの見出し")
	assert_eq(book.entries[-2].turn, 1)
	assert_eq(book.entries[-2].phase, P2)
	assert_true(book.entries[-1].text.begins_with("赤のスナイパーが回復の泉で "), book.entries[-1].text)


func test_spawns_in_a_row_are_one_line() -> void:
	var battle := Maps.battle(["*....*"])
	var book := BattleLog.new(battle)
	battle.phase = P2
	_apply(battle, book, EndPhaseAction.new())
	var spawned := _lines(book).filter(func(line: String) -> bool: return line.contains("湧いた"))
	assert_eq(spawned, ["エナジー・コアが 2 体湧いた: (0, 0)、(5, 0)"])


func test_take_changes_reports_rewritten_lines() -> void:
	var battle := Maps.battle(["......"])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var book := BattleLog.new(battle)
	assert_eq(book.take_changes(), 0)
	_apply(battle, book, MoveAction.new(sniper.id, Vector2i(2, 0)))
	assert_eq(book.take_changes(), 1)
	assert_eq(book.take_changes(), 2, "書き換えていなければ、行の数")
	_apply(battle, book, WaitAction.new(sniper.id))
	assert_eq(book.take_changes(), 1, "移動の行に「して待機」を書き足した")


## CPU どうしの 1 局（ほかのテストと共有する。tests/support/cpu_game.gd）を、最後まで読む。どの行も文があり、決着の行で終わる。
func test_whole_game_reads_without_gaps() -> void:
	var battle := CpuGame.start()
	var book := BattleLog.new(battle)
	CpuGame.replay(battle, func(result: ActionResult) -> void: book.feed_all(result.events))
	assert_true(battle.is_over(), "決着しなかった")
	var headers := 0
	for entry in book.entries:
		assert_ne(entry.text, "", "空の行")
		assert_false(entry.text.contains("駒 "), "知らない駒: %s" % entry.text)
		if entry.header:
			headers += 1
	assert_true(headers >= 3, "フェーズの見出しが少ない")
	assert_true(book.entries[-1].text.contains("の勝ち") or book.entries[-1].text.begins_with("引き分け"), book.entries[-1].text)
