extends "res://game/battle_source.gd"
## 対戦の設定画面（match_setup_panel.gd）で選ぶもの。選んだものから、ルールの対戦の設定（MatchSetup）を作る。
## 対戦モードの対戦の画面に渡すもの（battle_source.gd）でもある。ステージを替えてやり直せ、相手を切り替えられ、
## 対戦の途中で対戦の設定のパネルを開ける。
##
## 選べるのは、両方のプレイヤーの軍、人が動かすプレイヤーの部隊、ステージ、相手（人か CPU か）、CPU と対戦するときの人の手番（先手か後手か）。
## 人の部隊は、取っておいた部隊（deck_library.gd）か、軍ごとの既定の編成（MatchSetup.default_deck。部隊の id が空のとき）。
## CPU の編成は、いままでどおり CPU の編成（CpuDeck）。
## ここはノードに依存しない（テストから呼べる）。

const Run := preload("res://game/run.gd")
const SceneFlow := preload("res://game/scene_flow.gd")

var stage := BoardGenerator.Stage.PLAIN
## プレイヤー番号（0 が先手）ごとの軍。部隊を選んだら、その部隊の軍になる。
var armies: Array[UnitKind.Army] = [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]
## プレイヤー番号ごとの、選んだ部隊の id（空なら既定の編成）と、その中身（写し。選んだときのもの）。
var deck_ids: Array[String] = ["", ""]
var decks: Array[Deck] = [null, null]
## 相手を CPU が動かすか。偽なら、2 人が 1 台で交代する。
var cpu_opponent := true
## CPU と対戦するときに、人が動かすプレイヤー（PLAYER1 = 先手、PLAYER2 = 後手）。人どうしでは見ない。
var human_side := Unit.Side.PLAYER1


## CPU が動かすプレイヤー（cpu_opponent が偽でも、CPU に切り替えたときに動かすほう）。
func cpu_side() -> Unit.Side:
	return (1 - human_side) as Unit.Side


func look() -> StringName:
	return StageLook.name_of_stage(stage)


func make_setup(battle_seed: int) -> MatchSetup:
	return to_setup(battle_seed)


func can_switch_opponent() -> bool:
	return true


func set_cpu_opponent(cpu: bool) -> void:
	cpu_opponent = cpu


## 対戦モードで選べるステージ（ステージ選択のカードと同じ並び）。
func stages() -> Array[BoardGenerator.Stage]:
	var all: Array[BoardGenerator.Stage] = []
	for each: BoardGenerator.Stage in MatchSetup.STAGE_NAMES:
		all.append(each)
	return all


func choose_stage(to_stage: BoardGenerator.Stage) -> void:
	stage = to_stage


func can_open_setup() -> bool:
	return true


## この選択で始める流れ（run.gd）: 対戦の場面 1 つ。対戦の場面には、この選択の写しを渡す
## （対戦の途中でステージや相手を替えても、対戦の設定の場面に戻ったときの選択は変えない）。
func run() -> Run:
	var battle_run := Run.new()
	battle_run.add(SceneFlow.BATTLE, copy())
	return battle_run


## side が人の部隊を使うか（CPU が動かすプレイヤーは、いつも CPU の編成）。
func is_human(side: Unit.Side) -> bool:
	return not cpu_opponent or side == human_side


## side の軍を選ぶ。選んでいた部隊の軍と違えば、部隊は既定の編成に戻す。
func choose_army(side: Unit.Side, army: UnitKind.Army) -> void:
	armies[side] = army
	if decks[side] != null and decks[side].army != army:
		choose_default(side)


## side の部隊を、取っておいた部隊 id（中身 deck）にする。軍は部隊の軍になる。
func choose_deck(side: Unit.Side, id: String, deck: Deck) -> void:
	deck_ids[side] = id
	decks[side] = deck.copy()
	armies[side] = deck.army


## side の部隊を、軍の既定の編成にする。
func choose_default(side: Unit.Side) -> void:
	deck_ids[side] = ""
	decks[side] = null


## 取っておいた部隊の一覧（deck_library.gd）に合わせ直す。選んでいた部隊が消えた・出せなくなったら、既定の編成に戻す。
## 残っていれば、いまの中身にする（編成の画面で組み直したとき）。
func refresh_decks(library: RefCounted) -> void:
	for side in 2:
		if deck_ids[side] == "":
			continue
		var item: Variant = library.find(deck_ids[side]) if library != null else null
		if item == null or not item.playable() or item.deck.rules.id != DeckRules.VERSUS:
			choose_default(side as Unit.Side)
		else:
			choose_deck(side as Unit.Side, item.id, item.deck)


## side が対戦に出す編成（人なら選んだ部隊か既定の編成。CPU の編成は MatchSetup が作る）。
func deck_for(side: Unit.Side) -> Deck:
	if decks[side] != null:
		return decks[side].copy()
	return MatchSetup.default_deck(armies[side])


func copy() -> RefCounted:
	var other: RefCounted = get_script().new()
	other.stage = stage
	other.armies = armies.duplicate()
	other.deck_ids = deck_ids.duplicate()
	for side in 2:
		other.decks[side] = decks[side].copy() if decks[side] != null else null
	other.cpu_opponent = cpu_opponent
	other.human_side = human_side
	return other


## この選択で、種 battle_seed の対戦の設定を作る。
func to_setup(battle_seed: int) -> MatchSetup:
	if cpu_opponent:
		return MatchSetup.versus_cpu(stage, battle_seed, deck_for(human_side), armies[cpu_side()], human_side)
	return MatchSetup.versus_human(stage, battle_seed, deck_for(Unit.Side.PLAYER1), deck_for(Unit.Side.PLAYER2))
