extends "res://game/battle_source.gd"
## 対戦の設定画面（match_setup_panel.gd）で選ぶもの。選んだものから、ルールの対戦の設定（MatchSetup）を作る。
## 対戦モードの対戦の画面に渡すもの（battle_source.gd）でもある。ステージを替えてやり直せ、相手を切り替えられ、
## 対戦の途中で対戦の設定のパネルを開ける。
##
## 選べるのは、両方のプレイヤーの軍、人が動かすプレイヤーの部隊、ステージ（versus_fields.gd の鍵。生成のステージか手で作ったマップ）、相手（人か CPU か）、CPU と対戦するときの人の手番（先手か後手か）。
## 人の部隊は、取っておいた部隊（deck_library.gd）か、軍ごとの既定の編成（MatchSetup.default_deck。部隊の id が空のとき）。
## CPU の編成は、いままでどおり CPU の編成（CpuDeck）。
## ここはノードに依存しない（テストから呼べる）。

const Run := preload("res://game/run.gd")
const SceneFlow := preload("res://game/scene_flow.gd")
const VersusFields := preload("res://game/versus_fields.gd")

## ステージ（対戦モードで選べる盤の鍵。versus_fields.gd）。
var field: StringName = VersusFields.DEFAULT
## プレイヤー番号（0 が先手）ごとの軍。部隊を選んだら、その部隊の軍になる。
var armies: Array[UnitKind.Army] = [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]
## プレイヤー番号ごとの、選んだ部隊の id（空なら既定の編成）と、その中身（写し。選んだときのもの）。
var deck_ids: Array[String] = ["", ""]
var decks: Array[Deck] = [null, null]
## 相手を CPU が動かすか。偽なら、2 人が 1 台で交代する。
var cpu_opponent := true
## CPU と対戦するときに、人が動かすプレイヤー（PLAYER1 = 先手、PLAYER2 = 後手）。人どうしでは見ない。
## random_side が真なら見ない（対戦を作るたびに、種から引いた側。drawn_side）。
var human_side := Unit.Side.PLAYER1
## 手番を「ランダム」にしたか。真なら、対戦を作るとき（to_setup）に、種から先手・後手を引く。
var random_side := false
## 手番が「ランダム」のとき、最後に作った対戦で引いた、人が動かす側。
var drawn_side := Unit.Side.PLAYER1


## CPU と対戦するときに、人が動かすプレイヤー（ランダムなら、最後に作った対戦で引いた側）。
func human_side_now() -> Unit.Side:
	return drawn_side if random_side else human_side


## CPU が動かすプレイヤー（cpu_opponent が偽でも、CPU に切り替えたときに動かすほう）。
func cpu_side() -> Unit.Side:
	return (1 - human_side_now()) as Unit.Side


## 手番が「ランダム」のとき、種 battle_seed の対戦で人が動かす側。対戦の乱数とは別に引く（盤や対戦の進みを変えない）。
## 同じ種なら同じ側（「同じ盤面でもう一度」は同じ手番で始め直す）。
static func draw_side(battle_seed: int) -> Unit.Side:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([&"human_side", battle_seed])
	return rng.randi_range(0, 1) as Unit.Side


func look() -> StringName:
	return VersusFields.look_of(field)


func make_setup(battle_seed: int) -> MatchSetup:
	return to_setup(battle_seed)


func can_switch_opponent() -> bool:
	return true


func set_cpu_opponent(cpu: bool) -> void:
	cpu_opponent = cpu


## 「新しい盤面」で選べるステージ: 生成のステージ（ステージ選択のカードと同じ並び）。
## 手で作ったマップは、種を替えても同じ形なので入れない（同じマップは「同じ盤面でもう一度」、ほかのマップは対戦の設定から）。
func new_board_fields() -> Array[StringName]:
	return VersusFields.generated_ids()


func choose_field(to_field: StringName) -> void:
	field = to_field


func can_open_setup() -> bool:
	return true


## この選択で始める流れ（run.gd）: 対戦の場面 1 つ。対戦の場面には、この選択の写しを渡す
## （対戦の途中でステージや相手を替えても、対戦の設定の場面に戻ったときの選択は変えない）。
func run() -> Run:
	var battle_run := Run.new()
	battle_run.add(SceneFlow.BATTLE, copy())
	return battle_run


## 対戦の設定の「部隊を編成する」で始める流れ（run.gd）: 部隊の編成（対戦用。side の部隊を組む寄り道）→ 対戦の設定。
## 寄り道で取っておいた部隊は、戻った対戦の設定で side の部隊に選ばれる（deck_screen.gd の leave）。
static func deck_run(side: Unit.Side) -> Run:
	var detour := Run.new()
	detour.add(SceneFlow.DECKS, {"rules": DeckRules.VERSUS, "back_label": "setup.back", "side": side})
	detour.add(SceneFlow.SETUP)
	return detour


## side が人の部隊を使うか（CPU が動かすプレイヤーは、いつも CPU の編成）。
## 手番が「ランダム」なら、人の部隊は先手・後手のどちらに付くか決まっていないので、選ぶのは先手の行（PLAYER1）だけにする
## （対戦を作るとき、引いた側へ人の部隊を、もう一方へ CPU の編成を付ける）。
func is_human(side: Unit.Side) -> bool:
	if not cpu_opponent:
		return true
	return side == (Unit.Side.PLAYER1 if random_side else human_side)


## 人の部隊の行（CPU 戦）。ランダムなら先手の行（is_human を参照）。
func human_row() -> Unit.Side:
	return Unit.Side.PLAYER1 if random_side else human_side


## CPU の編成の行（CPU 戦）。ランダムなら後手の行。
func cpu_row() -> Unit.Side:
	return (1 - human_row()) as Unit.Side


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
	other.field = field
	other.armies = armies.duplicate()
	other.deck_ids = deck_ids.duplicate()
	for side in 2:
		other.decks[side] = decks[side].copy() if decks[side] != null else null
	other.cpu_opponent = cpu_opponent
	other.human_side = human_side
	other.random_side = random_side
	other.drawn_side = drawn_side
	return other


## この選択で、種 battle_seed の対戦の設定を作る。戦いの定義は、選んだステージの対戦モードのもの（versus_fields.gd）。
## 手番が「ランダム」なら、ここで種から引いた側を drawn_side に入れる（cpu_side() がそれを返す）。
func to_setup(battle_seed: int) -> MatchSetup:
	var defined := VersusFields.scenario_of(field)
	if random_side:
		drawn_side = draw_side(battle_seed)
	if cpu_opponent:
		return MatchSetup.on_scenario(defined, battle_seed, human_side_now(), deck_for(human_row()), armies[cpu_row()])
	return MatchSetup.humans_on(defined, battle_seed, deck_for(Unit.Side.PLAYER1), deck_for(Unit.Side.PLAYER2))
