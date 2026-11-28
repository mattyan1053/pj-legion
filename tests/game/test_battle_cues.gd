extends "res://tests/base_test.gd"
## 対戦の途中の会話（game/battle_cues.gd、game/battle_talk.gd。docs/story.md の「対戦の途中の会話」）。

const BattleCues := preload("res://game/battle_cues.gd")
const BattleTalk := preload("res://game/battle_talk.gd")
const BattleHud := preload("res://game/battle_hud.gd")
const BattleLog := preload("res://game/battle_log.gd")
const Story := preload("res://game/story.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const Maps := preload("res://tests/support/maps.gd")
const UnitIcons := preload("res://game/unit_icons.gd")

const NAMES := ["隊長", "敵将"]
const TalkCue := BattleCues.TalkCue


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
	var cues := BattleCues.new([_cue(BattleCues.TURN, 1, 0, "はじめ"), _cue(BattleCues.TURN, 2, 1, "ふたつめ")], NAMES)
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
	var cues := BattleCues.new([_cue(BattleCues.KING_HALF, 1, 1, "まだだ")], NAMES)
	var king := _king(battle, Unit.Side.PLAYER2)
	king.hp = king.max_hp() / 2 + (king.max_hp() % 2)
	assert_eq(cues.on_events(battle, []).size(), 0, "半分ちょうどでは、まだ")
	king.hp = (king.max_hp() - 1) / 2
	assert_eq(_texts(cues.on_events(battle, [])), ["まだだ"] as Array[String])
	assert_eq(cues.on_events(battle, []).size(), 0)


func test_fallen_fires_on_the_first_defeated_unit_of_that_side_but_not_the_king() -> void:
	var battle := _battle()
	var cues := BattleCues.new([_cue(BattleCues.FALLEN, 0, 0, "やられた")], NAMES)
	var foe: Unit = battle.units.filter(func(u: Unit) -> bool: return u.side == Unit.Side.PLAYER2 and u.kind != UnitKind.Id.KING)[0]
	var mine: Unit = battle.units.filter(func(u: Unit) -> bool: return u.side == Unit.Side.PLAYER1 and u.kind != UnitKind.Id.KING)[0]
	var events: Array[BattleEvent] = [UnitDefeatedEvent.new(foe), UnitDefeatedEvent.new(_king(battle, Unit.Side.PLAYER1))]
	assert_eq(cues.on_events(battle, events).size(), 0, "相手の駒と、将では出さない")
	events = [UnitDefeatedEvent.new(mine)]
	assert_eq(_texts(cues.on_events(battle, events)), ["やられた"] as Array[String])


## 軍略が初めて効いた: その陣営の軍略の出来事（補給線は回復）が来たら、1 度だけ。相手の陣営の軍略では出ない。
func test_trait_fires_when_that_side_trait_first_works() -> void:
	var battle := _battle()
	battle.traits = [Traits.Id.FOCUS, Traits.Id.VENGEANCE] as Array[int]
	var mine := _king(battle, Unit.Side.PLAYER1)
	var theirs := _king(battle, Unit.Side.PLAYER2)
	var cues := BattleCues.new([_cue(BattleCues.TRAIT, 0, 0, "効いた")], NAMES)
	var other: Array[BattleEvent] = [TraitTriggeredEvent.new(Traits.Id.VENGEANCE, theirs.id, mine.id, 4)]
	assert_eq(_texts(cues.on_events(battle, other)), [] as Array[String], "相手の軍略では出ない")
	var hit: Array[BattleEvent] = [TraitTriggeredEvent.new(Traits.Id.FOCUS, mine.id, theirs.id, 2)]
	assert_eq(_texts(cues.on_events(battle, hit)), ["効いた"] as Array[String])
	assert_eq(_texts(cues.on_events(battle, hit)), [] as Array[String], "1 度だけ")
	battle.traits[0] = Traits.Id.SUPPLY
	var supply := BattleCues.new([_cue(BattleCues.TRAIT, 0, 0, "治った")], NAMES)
	var healed: Array[BattleEvent] = [SupplyHealedEvent.new(mine.id, mine.id, 4, 10)]
	assert_eq(_texts(supply.on_events(battle, healed)), ["治った"] as Array[String], "補給線は回復で")


func test_nothing_is_said_once_the_battle_is_over() -> void:
	var battle := _battle()
	var cues := BattleCues.new([_cue(BattleCues.TURN, 1, 0, "はじめ"), _cue(BattleCues.KING_HALF, 1, 1, "まだだ")], NAMES)
	_king(battle, Unit.Side.PLAYER2).hp = 1
	battle.winner = Unit.Side.PLAYER1
	assert_true(battle.is_over())
	assert_eq(cues.on_start(battle).size(), 0, "決着と同時なら、決着の画面と重ねない")
	assert_eq(cues.on_events(battle, []).size(), 0)


func test_several_cues_at_once_keep_their_order() -> void:
	var battle := _battle()
	var cues := BattleCues.new([_cue(BattleCues.KING_HALF, 1, 1, "二"), _cue(BattleCues.TURN, 1, 0, "一")], NAMES)
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
		for cue: TalkCue in cues:
			assert_true(BattleCues.KINDS.has(cue.trigger), "%s: 知らないきっかけ %s" % [episode.id, cue.trigger])
			assert_true(cue.line.side in [0, 1], "話し手の陣営は 0 か 1")
			assert_eq(episode.speaker_sides[cue.line.who], cue.line.side, "%s: 話し手の番号と陣営が合う" % episode.id)
			assert_ne(cue.line.text, "")
			assert_true(cue.line.text.length() <= 40, "%s: 札に収まる短さ（1〜2 行）" % episode.id)
			if cue.trigger == BattleCues.TURN and episode.hold_turns > 0:
				assert_true(cue.value <= episode.hold_turns, "守り切るターンの中")
	assert_true(with_cues >= Story.military().episodes.size(), "どの話にも、使い方の例を 1 つ以上")


func test_story_battles_hand_their_cues_to_the_battle_screen() -> void:
	var episode: RefCounted = Story.military().episodes[0]
	var cues: BattleCues = Story.first_battle(episode).talk_cues()
	assert_false(cues.is_empty())
	assert_true(MatchChoiceProbe.new().talk_cues().is_empty(), "対戦モードは台詞なし")


## 台詞は、話し手の姿（話のファイルの figure）を持ち、札は名前の左にその姿のアイコン（胸から上）を出す。
func test_lines_carry_the_speaker_figure_and_the_card_shows_its_icon() -> void:
	var figures := [{"kind": UnitKind.Id.SNIPER, "evolved": true}, {"kind": UnitKind.Id.SKELETON, "evolved": false}]
	var cues := BattleCues.new([_cue(BattleCues.TURN, 1, 1, "来たか")], NAMES, figures)
	var lines := cues.on_start(_battle())
	assert_eq(lines[0].figure, figures[1])
	var talk := BattleTalk.new()
	talk.say(lines)
	assert_eq(talk.face(), UnitIcons.bust(UnitKind.Id.SKELETON, 1), "敵の陣営の色の、骸骨兵のアイコン")
	talk.clear()
	# 話し手の番号（5 つ目）があれば、その話し手の名前と姿（同じ陣営に何人いてもよい）。
	var more_names := ["隊長", "敵将", "新兵"]
	var more_figures := figures + [{"kind": UnitKind.Id.MEDIC, "evolved": false}]
	var by_who := BattleCues.new([_cue(BattleCues.TURN, 1, 0, "はい", 2)], more_names, more_figures).on_start(_battle())
	assert_eq([by_who[0].side, by_who[0].name, by_who[0].figure], [0, "新兵", more_figures[2]])
	talk.say([BattleCues.Line.new(0, "隊長", "一")] as Array[BattleCues.Line])
	assert_eq(talk.face(), null, "姿の無い台詞は、アイコンを出さない")
	talk.free()
	var episode: RefCounted = Story.military().episodes[0]
	var first: BattleCues.Line = Story.first_battle(episode).talk_cues().on_start(Story.first_battle(episode).make_setup(1).create_battle())[0]
	assert_eq(first.figure, episode.figures[episode.speakers.find(first.name)], "話の対戦の台詞は、その話し手の姿を持つ")


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


## 画面の真ん中の「ターン N」の帯が出ている間は、台詞を出し始めない（帯に目が行って、気付かないうちに消えるので）。
## 出し始めた台詞は、帯が出ても止めない。
func test_talk_card_waits_for_the_banner_before_starting_a_line() -> void:
	var talk := BattleTalk.new()
	var banner := [true]
	talk.waiting = func() -> bool: return banner[0]
	talk.say([BattleCues.Line.new(0, "隊長", "一"), BattleCues.Line.new(1, "敵将", "二")] as Array[BattleCues.Line])
	talk._process(100.0)
	assert_eq(talk.current().text, "一", "帯が出ている間に、台詞が進んだ")
	assert_eq(talk.modulate.a, 0.0, "帯が出ている間に、台詞が見えている")
	banner[0] = false
	talk._process(1.0)
	assert_true(talk.modulate.a > 0.0)
	banner[0] = true
	talk._process(BattleTalk.SHOW_BASE)
	assert_eq(talk.current().text, "二", "出し始めた台詞が、帯で止まった")
	talk._process(100.0)
	assert_eq(talk.current().text, "二", "次の台詞も、帯が消えるまで待つ")
	talk.free()


## 遊ぶとき（hold）は、台詞を自動で消さず、送られるまで出したままにする。出し始める前（帯を待つ間・フェードの途中）は送れない。
func test_held_talk_card_waits_to_be_advanced() -> void:
	var talk := BattleTalk.new()
	talk.hold = true
	var drained := [0]
	talk.drained.connect(func() -> void: drained[0] += 1)
	talk.say([BattleCues.Line.new(0, "隊長", "一"), BattleCues.Line.new(1, "敵将", "二")] as Array[BattleCues.Line])
	assert_true(talk.is_holding())
	assert_false(talk.advance(), "出し始める前に送れた（押した勢いで、読む前に消える）")
	talk._process(100.0)
	assert_eq(talk.current().text, "一", "送る前に、台詞が消えた")
	assert_true(talk.advance())
	assert_eq(talk.current().text, "二")
	talk._process(1.0)
	assert_true(talk.advance())
	assert_false(talk.is_holding(), "送り終えても、待っている")
	assert_false(talk.visible)
	assert_eq(drained[0], 1, "送り終えたことを知らせない")
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


## 途中の台詞 1 つ（話し手の番号 who を書かなければ、陣営の主な話し手）。
static func _cue(trigger: StringName, value: int, side: int, text: String, who := -1) -> TalkCue:
	return TalkCue.new(trigger, value, TalkCue.TalkLine.speech(side, text, side if who < 0 else who))
