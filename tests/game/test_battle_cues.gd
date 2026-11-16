extends "res://tests/base_test.gd"
## 対戦の途中の会話（game/battle_cues.gd、game/battle_talk.gd。docs/story.md の「対戦の途中の会話」）。

const BattleCues := preload("res://game/battle_cues.gd")
const BattleTalk := preload("res://game/battle_talk.gd")
const BattleHud := preload("res://game/battle_hud.gd")
const BattleLog := preload("res://game/battle_log.gd")
const Story := preload("res://game/story.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const Maps := preload("res://tests/support/maps.gd")

const NAMES := ["隊長", "敵将"]


func _battle() -> Battle:
	var setup := MatchSetup.versus_human(
		BoardGenerator.Stage.PLAIN, 1, MatchSetup.default_deck(UnitKind.Army.MILITARY), MatchSetup.default_deck(UnitKind.Army.FANTASY)
	)
	return setup.create_battle()


func _king(battle: Battle, side: Unit.Side) -> Unit:
	for unit in battle.units:
		if unit.kind == UnitKind.Id.KING and unit.side == side:
			return unit
	return null


func _texts(lines: Array[BattleCues.Line]) -> Array[String]:
	var texts: Array[String] = []
	for line in lines:
		texts.append(line.text)
	return texts


func test_turn_cue_fires_at_the_start_of_the_human_turn_once() -> void:
	var battle := _battle()
	var cues := BattleCues.new([[BattleCues.TURN, 1, 0, "はじめ"], [BattleCues.TURN, 2, 1, "ふたつめ"]], NAMES)
	var first := cues.on_start(battle)
	assert_eq(_texts(first), ["はじめ"] as Array[String], "ターン 1 は、対戦の始めに出す")
	assert_eq(first[0].name, "隊長")
	assert_eq(first[0].side, 0)
	var events: Array[BattleEvent] = [PhaseStartedEvent.new(2, Unit.Side.PLAYER2)]
	assert_eq(cues.on_events(battle, events).size(), 0, "相手の番の始めには出さない")
	events = [PhaseStartedEvent.new(2, Unit.Side.PLAYER1)]
	assert_eq(_texts(cues.on_events(battle, events)), ["ふたつめ"] as Array[String])
	assert_eq(cues.on_events(battle, events).size(), 0, "1 回の対戦で 1 度だけ")


func test_king_half_fires_when_the_king_drops_below_half() -> void:
	var battle := _battle()
	var cues := BattleCues.new([[BattleCues.KING_HALF, 1, 1, "まだだ"]], NAMES)
	var king := _king(battle, Unit.Side.PLAYER2)
	king.hp = king.max_hp() / 2 + (king.max_hp() % 2)
	assert_eq(cues.on_events(battle, []).size(), 0, "半分ちょうどでは、まだ")
	king.hp = (king.max_hp() - 1) / 2
	assert_eq(_texts(cues.on_events(battle, [])), ["まだだ"] as Array[String])
	assert_eq(cues.on_events(battle, []).size(), 0)


func test_fallen_fires_on_the_first_defeated_unit_of_that_side_but_not_the_king() -> void:
	var battle := _battle()
	var cues := BattleCues.new([[BattleCues.FALLEN, 0, 0, "やられた"]], NAMES)
	var foe: Unit = battle.units.filter(func(u: Unit) -> bool: return u.side == Unit.Side.PLAYER2 and u.kind != UnitKind.Id.KING)[0]
	var mine: Unit = battle.units.filter(func(u: Unit) -> bool: return u.side == Unit.Side.PLAYER1 and u.kind != UnitKind.Id.KING)[0]
	var events: Array[BattleEvent] = [UnitDefeatedEvent.new(foe), UnitDefeatedEvent.new(_king(battle, Unit.Side.PLAYER1))]
	assert_eq(cues.on_events(battle, events).size(), 0, "相手の駒と、将では出さない")
	events = [UnitDefeatedEvent.new(mine)]
	assert_eq(_texts(cues.on_events(battle, events)), ["やられた"] as Array[String])


func test_nothing_is_said_once_the_battle_is_over() -> void:
	var battle := _battle()
	var cues := BattleCues.new([[BattleCues.TURN, 1, 0, "はじめ"], [BattleCues.KING_HALF, 1, 1, "まだだ"]], NAMES)
	_king(battle, Unit.Side.PLAYER2).hp = 1
	battle.winner = Unit.Side.PLAYER1
	assert_true(battle.is_over())
	assert_eq(cues.on_start(battle).size(), 0, "決着と同時なら、決着の画面と重ねない")
	assert_eq(cues.on_events(battle, []).size(), 0)


func test_several_cues_at_once_keep_their_order() -> void:
	var battle := _battle()
	var cues := BattleCues.new([[BattleCues.KING_HALF, 1, 1, "二"], [BattleCues.TURN, 1, 0, "一"]], NAMES)
	_king(battle, Unit.Side.PLAYER2).hp = 1
	assert_eq(_texts(cues.on_start(battle)), ["二", "一"] as Array[String], "[cues] の並びの順")


func test_every_episode_cue_is_well_formed() -> void:
	var with_cues := 0
	for episode in Story.all_episodes():
		var cues := episode.cues
		if cues.is_empty():
			continue
		with_cues += 1
		assert_between(cues.size(), 1, 3, "%s: 途中の会話は少なく" % episode.id)
		for cue: Array in cues:
			assert_eq(cue.size(), 4, episode.id)
			assert_true(BattleCues.KINDS.has(cue[0]), "%s: 知らないきっかけ %s" % [episode.id, cue[0]])
			assert_true(cue[2] in [0, 1], "話し手は 0 か 1")
			assert_ne(cue[3], "")
			assert_true(String(cue[3]).length() <= 40, "%s: 札に収まる短さ（1〜2 行）" % episode.id)
			if cue[0] == BattleCues.TURN and episode.hold_turns > 0:
				assert_true(cue[1] <= episode.hold_turns, "守り切るターンの中")
	assert_true(with_cues >= Story.military().episodes.size(), "どの話にも、使い方の例を 1 つ以上")


func test_story_battles_hand_their_cues_to_the_battle_screen() -> void:
	var episode: RefCounted = Story.military().episodes[0]
	var cues: BattleCues = Story.first_battle(episode).talk_cues()
	assert_false(cues.is_empty())
	assert_true(MatchChoiceProbe.new().talk_cues().is_empty(), "対戦モードは台詞なし")


func test_said_lines_are_written_to_the_log() -> void:
	var battle := _battle()
	var log := BattleLog.new(battle)
	log.say("隊長", "進め", 0)
	assert_eq(log.entries[-1].text, "隊長「進め」")
	assert_eq(log.entries[-1].side, 0)


func test_talk_card_shows_lines_in_order_for_real_seconds() -> void:
	var talk := BattleTalk.new()
	var lines: Array[BattleCues.Line] = [BattleCues.Line.new(0, "隊長", "一"), BattleCues.Line.new(1, "敵将", "二")]
	talk.say(lines)
	assert_eq(talk.current().text, "一")
	assert_eq(talk.pending(), 1)
	var scale := Engine.time_scale
	Engine.time_scale = 8.0  # CPU の番の早送り: 実際の秒で測るので、縮まない
	talk._process(8.0 * (BattleTalk.SHOW_BASE - 0.5))
	assert_eq(talk.current().text, "一", "早送りでも、読める時間は変わらない")
	talk._process(8.0 * 1.0)
	assert_eq(talk.current().text, "二", "前の台詞が消えてから次")
	Engine.time_scale = 0.0  # メニューで止めている間は進めない
	talk._process(100.0)
	assert_eq(talk.current().text, "二")
	Engine.time_scale = scale
	talk.clear()
	assert_eq(talk.current(), null)
	assert_false(talk.visible)
	talk.free()


class MatchChoiceProbe:
	extends "res://game/match_choice.gd"


## 札はクリックを受けないので、駒のそばのメニュー・予測のパネル・進化の選択より下に描く（隠れたボタンを押せてしまわない）。
func test_talk_card_is_drawn_under_the_rest_of_the_hud() -> void:
	var hud := BattleHud.new()
	hud.setup([Color.BLUE, Color.RED, Color.GRAY] as Array[Color])
	var card := BattleTalk.new()
	hud.add_talk_card(card)
	assert_eq(card.get_index(), 0, "札が、ほかの帯や枠より上に描かれる")
	assert_true(hud.get_child_count() > 1)
	hud.free()
