extends "res://tests/base_test.gd"
## 組み方の画面の文（game/formation_text.gd、BattleTexts.formation_notice。docs/formation.md の「画面」）。

const FormationText := preload("res://game/formation_text.gd")
const BattleTexts := preload("res://game/battle_texts.gd")
const Names := preload("res://game/names.gd")
const Maps := preload("res://tests/support/maps.gd")

const K := UnitKind.Id


func _battle(formation := true) -> Battle:
	var battle := Maps.battle([".......", ".......", ".......", ".......", "......."])
	battle.formation = formation
	return battle


func test_unit_lines_show_the_squad_and_whether_it_guards() -> void:
	var battle := _battle()
	var a := battle.add_unit(K.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 0))
	var b := battle.add_unit(K.SNIPER, Unit.Side.PLAYER1, Vector2i(3, 3))
	var lines := FormationText.unit_lines(battle, a)
	assert_eq(lines.size(), 1)
	assert_true(lines[0].contains(Names.kind(K.SNIPER) + " 2 体"), lines[0])
	assert_false(lines[0].contains("肩並べ中"), lines[0])
	b.cell = Vector2i(1, 1)
	assert_true(FormationText.unit_lines(battle, a)[0].contains("肩並べ中"))


func test_unit_lines_show_the_oath_partner_and_the_foe() -> void:
	var battle := _battle()
	var knight := battle.add_unit(K.PALADIN, Unit.Side.PLAYER2, Vector2i(0, 0))
	var mage := battle.add_unit(K.SORCERER, Unit.Side.PLAYER2, Vector2i(5, 4))
	var foe := battle.add_unit(K.COMMANDO, Unit.Side.PLAYER1, Vector2i(1, 0))
	Formation.bind(knight, mage)
	var far := FormationText.unit_lines(battle, knight)
	assert_eq(far.size(), 1)
	assert_true(far[0].contains(Names.kind(K.SORCERER)) and far[0].contains("離れている"), far[0])
	mage.cell = Vector2i(1, 1)
	mage.oath_foe = foe.id
	var near := FormationText.unit_lines(battle, knight)
	assert_eq(near.size(), 2, str(near))
	assert_true(near[0].contains("届く"), near[0])
	assert_true(near[1].contains(Names.kind(K.COMMANDO)), near[1])


func test_nothing_is_shown_when_the_rule_is_off() -> void:
	var battle := _battle(false)
	var a := battle.add_unit(K.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 0))
	battle.add_unit(K.SNIPER, Unit.Side.PLAYER1, Vector2i(1, 1))
	assert_eq(FormationText.unit_lines(battle, a), [] as Array[String])
	assert_eq(BattleTexts.formation_notice(battle), [] as Array[String])
	assert_eq(BattleTexts.rule_notice(battle), [] as Array[String])


func test_notice_has_one_line_per_army() -> void:
	var battle := _battle()
	battle.add_unit(K.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 0))
	battle.add_unit(K.PALADIN, Unit.Side.PLAYER2, Vector2i(6, 4))
	var lines := BattleTexts.rule_notice(battle)
	assert_eq(lines.size(), 2, str(lines))
	assert_true(lines[0].contains("分隊") and lines[1].contains("誓い"), str(lines))


func test_deck_text_tells_what_is_formed() -> void:
	var federation := Deck.new(UnitKind.Army.MILITARY)
	federation.add(K.SNIPER)
	assert_true(FormationText.deck_text(federation).contains("分隊なし"))
	federation.add(K.SNIPER)
	assert_true(FormationText.deck_text(federation).contains(Names.kind(K.SNIPER) + " 2 体"))
	var knights := Deck.new(UnitKind.Army.FANTASY)
	var a := knights.add(K.PALADIN)
	var b := knights.add(K.SORCERER)
	assert_true(FormationText.deck_text(knights).contains("誓いなし"))
	assert_true(FormationText.deck_text(knights, 0).contains("選択中"))
	knights.bind(a, b)
	assert_true(FormationText.deck_text(knights).contains(Names.kind(K.PALADIN) + "・" + Names.kind(K.SORCERER)))
	assert_eq(FormationText.oath_tag(knights, b), "誓い 1")
	assert_true(FormationText.oath_tooltip(knights, a).contains(Names.kind(K.SORCERER)))


func test_saved_decks_keep_their_oaths() -> void:
	const DeckLibrary := preload("res://game/deck_library.gd")
	var knights := Deck.new(UnitKind.Army.FANTASY)
	var a := knights.add(K.PALADIN)
	knights.add(K.PRIEST)
	var c := knights.add(K.SORCERER)
	knights.bind(a, c)
	var record := DeckLibrary.deck_to_record(knights)
	assert_eq(record.get("oaths"), [[0, 2]])
	record["id"] = "1"
	var read: Deck = DeckLibrary._from_record(record).deck
	assert_eq(read.oath_pairs(), [Vector2i(0, 2)] as Array[Vector2i])
	record["oaths"] = [[0, 9], "x", [1, 1]]
	assert_eq(DeckLibrary._from_record(record).deck.oaths, [] as Array[Array], "読めない組は捨てる")
	record["units"] = [{"kind": "NO_SUCH_UNIT"}, {"kind": "PALADIN"}, {"kind": "SORCERER"}, {"kind": "PRIEST"}]
	record["oaths"] = [[1, 2], [0, 3]]
	var kept: Deck = DeckLibrary._from_record(record).deck
	assert_eq(kept.oath_pairs(), [Vector2i(0, 1)] as Array[Vector2i], "誓いの添字はファイルの並び。外した駒を含む組は捨てる")
	assert_false(DeckLibrary.deck_to_record(Deck.new(UnitKind.Army.MILITARY)).has("oaths"), "誓いが無ければ書かない（いまのファイルと同じ形）")
