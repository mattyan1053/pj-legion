extends "res://game/battle_source.gd"
## 対戦設定画面（match_setup_panel.gd）で選ぶもの。選んだものから、ルールの対戦設定（MatchSetup）を作る。
## 対戦モードの対戦の画面に渡すもの（battle_source.gd）でもある。マップを替えてやり直せ、相手を切り替えられ、
## 対戦の途中で対戦設定のパネルを開ける。
##
## 選べるのは、両方のプレイヤーの軍、人が動かすプレイヤーの部隊、マップ（versus_fields.gd の鍵。生成のマップか手で作ったマップ）、相手（人か CPU か）、CPU と対戦するときの人の手番（先手か後手か）。
## 部隊は、人の行も CPU の行も同じ選び方: 軍ごとの既定の編成（部隊の id が空のとき。人なら MatchSetup.default_deck、CPU なら CPU の編成（CpuDeck）。中身は同じ）、
## 取っておいた部隊（deck_library.gd）、ランダム編成（RANDOM。対戦を作るたびに、対戦の種から決まりの中でランダムに組む。random_squad.gd）。
## ここはノードに依存しない（テストから呼べる）。

const Run := preload("res://game/run.gd")
const SceneFlow := preload("res://game/scene_flow.gd")
const VersusFields := preload("res://game/versus_fields.gd")
const RandomSquad := preload("res://game/random_squad.gd")

## 部隊の id の「ランダム編成」（取っておいた部隊の id と重ならない）。
const RANDOM := "@random"

## マップ（対戦モードで選べる盤の鍵。versus_fields.gd）。
var field: StringName = VersusFields.DEFAULT
## プレイヤー番号（0 が先手）ごとの軍。部隊を選んだら、その部隊の軍になる。
var armies: Array[UnitKind.Army] = [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]
## プレイヤー番号（行）ごとの、選んだ部隊の id（空なら既定の編成、RANDOM ならランダム編成）と、その中身（写し。選んだときのもの。既定とランダム編成は null）。
var deck_ids: Array[String] = ["", ""]
var decks: Array[Deck] = [null, null]
## 行ごとの、最後に作った対戦で、ランダム編成で組んだ部隊（ランダム編成でない行や、まだ対戦を作っていなければ null）。「編成確認」で見せる。
var drawn_decks: Array[Deck] = [null, null]
## 相手を CPU が動かすか。偽なら、2 人が 1 台で交代する。
var cpu_opponent := true
## CPU と対戦するときに、人が動かすプレイヤー（PLAYER1 = 先手、PLAYER2 = 後手）。人どうしでは見ない。
## random_side が真なら見ない（対戦を作るたびに、種から引いた側。drawn_side）。
var human_side := Unit.Side.PLAYER1
## 手番を「ランダム」にしたか。真なら、対戦を作るとき（to_setup）に、種から先手・後手を引く。
var random_side := false
## 手番が「ランダム」のとき、最後に作った対戦で引いた、人が動かす側。
var drawn_side := Unit.Side.PLAYER1
## 行ごとの、人が決めた初期位置（本陣からのずれ。部隊の並びの順。空ならいつもの置き方。MatchSetup.placements）。
## その行が先手（下の本陣）として決めたもの。後手として対戦する（手番がランダム）ときは、上下を返して使う。部隊を替えたら空に戻す。
var placements: Array[Array] = [[], []]


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


## 「新しい盤面」で選べるマップ: 生成のマップ（マップ選択のカードと同じ並び）。
## 手で作ったマップは、種を替えても同じ形なので入れない（同じマップは「同じ盤面でもう一度」、ほかのマップは対戦設定から）。
func new_board_fields() -> Array[StringName]:
	return VersusFields.generated_ids()


func choose_field(to_field: StringName) -> void:
	field = to_field


func can_open_setup() -> bool:
	return true


## 決着の画面の、流れの外への行き先はマップ選択（別のマップで遊ぶ。タイトルへはシステムメニューから）。
func leave() -> Array:
	return [&"map_select", "result.to_map_select"]


## この選択で始める流れ（run.gd）: 対戦の場面 1 つ。対戦の場面には、この選択の写しを渡す
## （対戦の途中でマップや相手を替えても、対戦設定の場面に戻ったときの選択は変えない）。
func run() -> Run:
	var battle_run := Run.new()
	battle_run.menu_exits = [[SceneFlow.MAP_SELECT, "map_select.resume", "menu.to_map_select.confirm"]]
	battle_run.add(SceneFlow.BATTLE, copy())
	return battle_run


## 対戦設定（とマップ選択）の「部隊編成」で始める流れ（run.gd）: 部隊編成（対戦用。side の部隊を組む寄り道）→ 戻り先 back_to（既定は対戦設定）。
## 寄り道で取っておいた部隊は、対戦設定の side の部隊に選ばれる（deck_screen.gd の leave）。back_label は編成の「戻る」の文字の鍵。
static func deck_run(side: Unit.Side, back_to := SceneFlow.SETUP, back_label := "setup.back") -> Run:
	var detour := Run.new()
	detour.add(SceneFlow.DECKS, {"rules": DeckRules.VERSUS, "back_label": back_label, "side": side})
	detour.add(back_to)
	return detour


## side の行を人が動かすか（偽なら CPU が動かす）。
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
	if armies[side] != army:
		placements[side] = []
	armies[side] = army
	if decks[side] != null and decks[side].army != army:
		choose_default(side)


## side の部隊を、取っておいた部隊 id（中身 deck）にする。軍は部隊の軍になる。
func choose_deck(side: Unit.Side, id: String, deck: Deck) -> void:
	placements[side] = []
	deck_ids[side] = id
	decks[side] = deck.copy()
	drawn_decks[side] = null
	armies[side] = deck.army


## side の部隊を、軍の既定の編成にする。
func choose_default(side: Unit.Side) -> void:
	placements[side] = []
	deck_ids[side] = ""
	decks[side] = null
	drawn_decks[side] = null


## side の部隊を、ランダム編成（対戦を作るたびに、種から決まりの中でランダムに組む）にする。
func choose_random(side: Unit.Side) -> void:
	placements[side] = []
	deck_ids[side] = RANDOM
	decks[side] = null
	drawn_decks[side] = null


func is_random(side: Unit.Side) -> bool:
	return deck_ids[side] == RANDOM


## side の行の、最後に作った対戦でランダム編成で組んだ部隊（写し）。ランダム編成でないか、まだ組んでいなければ null。
func drawn_deck(side: Unit.Side) -> Deck:
	if not is_random(side) or drawn_decks[side] == null or drawn_decks[side].army != armies[side]:
		return null
	return drawn_decks[side].copy()


## 取っておいた部隊の一覧（deck_library.gd）に合わせ直す。選んでいた部隊が消えた・出せなくなったら、既定の編成に戻す。
## 残っていれば、いまの中身にする（編成の画面で組み直したとき）。
func refresh_decks(library: RefCounted) -> void:
	for side in 2:
		if deck_ids[side] == "" or deck_ids[side] == RANDOM:
			continue
		var item: Variant = library.find(deck_ids[side]) if library != null else null
		if item == null or not item.playable() or item.deck.rules.id != DeckRules.VERSUS:
			choose_default(side as Unit.Side)
		else:
			choose_deck(side as Unit.Side, item.id, item.deck)


## side の行が対戦に出す編成: 選んだ部隊か、既定の編成。ランダム編成なら、種 battle_seed の対戦で、プレイヤー plays_as として組む部隊
## （random_squad.gd。同じ種なら同じ部隊）。plays_as が負なら side。
func deck_for(side: Unit.Side, battle_seed := 0, plays_as := -1) -> Deck:
	if is_random(side):
		return RandomSquad.for_battle(armies[side], battle_seed, (side if plays_as < 0 else plays_as) as Unit.Side)
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
		other.drawn_decks[side] = drawn_decks[side].copy() if drawn_decks[side] != null else null
	other.cpu_opponent = cpu_opponent
	other.human_side = human_side
	other.random_side = random_side
	other.drawn_side = drawn_side
	for side in 2:
		other.placements[side] = placements[side].duplicate()
	return other


## 行 row の初期位置を決める画面に見せる対戦（始まる前。row が先手・後手のその側として、種 battle_seed で作る）と、
## row が決めた初期位置を使わない、いつもの置き方の対戦。[決めた置き方の対戦, いつもの対戦, row が動かすプレイヤー]。
func placement_preview(row: Unit.Side, battle_seed: int) -> Array:
	var shown: RefCounted = copy()
	shown.random_side = false
	if shown.cpu_opponent:
		shown.human_side = row
	var placed: Battle = shown.to_setup(battle_seed).create_battle()
	shown.placements[row] = []
	var usual: Battle = shown.to_setup(battle_seed).create_battle()
	return [placed, usual, row]


## この選択で、種 battle_seed の対戦設定を作る。戦いの定義は、選んだマップの対戦モードのもの（versus_fields.gd）。
## 手番が「ランダム」なら、ここで種から引いた側を drawn_side に入れる（cpu_side() がそれを返す）。
func to_setup(battle_seed: int) -> MatchSetup:
	var defined := VersusFields.scenario_of(field)
	if random_side:
		drawn_side = draw_side(battle_seed)
	var setup: MatchSetup
	if cpu_opponent:
		var human_deck := deck_for(human_row(), battle_seed, human_side_now())
		setup = MatchSetup.on_scenario(defined, battle_seed, human_side_now(), human_deck, armies[cpu_row()])
		# CPU の行で選んだ部隊（既定なら、on_scenario が作った CPU の編成のまま）。
		if deck_ids[cpu_row()] != "" and not defined.is_fixed(cpu_side()):
			setup.decks[cpu_side()] = deck_for(cpu_row(), battle_seed, cpu_side())
	else:
		setup = MatchSetup.humans_on(defined, battle_seed, deck_for(Unit.Side.PLAYER1, battle_seed), deck_for(Unit.Side.PLAYER2, battle_seed))
	# 人が決めた初期位置（行ごと）。後手として対戦する行は、上下を返す。部隊の数と合わなければ使わない。
	for row in 2:
		var plays_as: int = row if not cpu_opponent else (human_side_now() if row == human_row() else cpu_side())
		if not is_human(row as Unit.Side) or placements[row].is_empty() or setup.decks[plays_as] == null \
				or placements[row].size() != setup.decks[plays_as].entries.size():
			continue
		var placement: Array[Vector2i] = []
		for offset: Vector2i in placements[row]:
			placement.append(offset if plays_as == row or offset == Deployment.UNSET else Vector2i(offset.x, -offset.y))
		setup.placements[plays_as] = placement
	# ランダム編成で組んだ部隊を覚える（「編成確認」で見せる）。行と、実際に動かすプレイヤーは、手番がランダムのときに違う。
	for row in 2:
		var plays_as: int = row if not cpu_opponent else (human_side_now() if row == human_row() else cpu_side())
		drawn_decks[row] = setup.decks[plays_as].copy() if is_random(row as Unit.Side) and setup.decks[plays_as] != null else null
	return setup
