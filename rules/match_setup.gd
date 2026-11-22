class_name MatchSetup
extends RefCounted
## 1 回の対戦を始めるのに要るものを 1 つにまとめた値（docs/match-setup.md）。
## 戦いの定義（Scenario。盤の出どころ、初期位置、決め打ちの部隊、勝ちの条件）、盤面と対戦の種、両方のプレイヤーの編成（軍を含む）、
## どちらを人が動かし、どちらを CPU が動かすか。
##
## 対戦（Battle）は create_battle() だけから作る。対戦の画面、検査の自動の対戦、集計の道具が同じ入口を通る。
## 添字のある値は、プレイヤー番号（Unit.Side.PLAYER1 = 0 が先手、PLAYER2 = 1 が後手）ごと。
## 先手・後手は、どちらのプレイヤー番号を人が動かすかで表す（ルールでは、いつもプレイヤー1 から動く）。

## そのプレイヤーを誰が動かすか。
enum Controller {
	HUMAN,  ## 人が画面で操作する
	CPU,  ## CpuPlayer が動かす
}

## 対戦を始められない理由。
enum Problem {
	NO_DECK,  ## 編成が渡されていないプレイヤーがいる
	INVALID_DECK,  ## 対戦に出せない編成（Deck.problems() が空でない）のプレイヤーがいる
	NO_BOARD,  ## 盤面を作れない（盤面が小さすぎる、手で作ったマップが盤にできない）
}

## 戦いの定義。既定は、対戦モードの中央平原。
var scenario := Scenario.versus(BoardGenerator.Stage.PLAIN)
## 盤面の生成と、対戦の乱数（Battle.rng）の両方に使う種。同じ設定からは、いつも同じ対戦ができる。
var battle_seed := 0
## プレイヤーごとの選んだ編成。戦いの定義が部隊を決め打ちにしているプレイヤーの分は使わない（deck_of）。
var decks: Array[Deck] = [null, null]
var controllers: Array[Controller] = [Controller.HUMAN, Controller.HUMAN]
## 予算を超えた編成も通す。集計の道具の「両軍とも同じ役割の 6 体」（tools/cpu_matches.gd の --decks=even）だけが使う。
## 予算のほかの検査（駒の数、装備の数、ロスター）は、これを立てても通らない。
var ignore_budget := false
## 人が決めた初期位置（プレイヤーごと。本陣からのずれを、編成の並びの順に。決めていない駒は Deployment.UNSET）。
## 空なら、いつもの置き方（Deployment.deploy）。置けるマス（Deployment.zone）の外のずれは使わない。
var placements: Array[Array] = [[], []]
## 入にする選べる決まり（TrialRules の名前）。既定は空（どれも切）。
var trials: Array[StringName] = []


## 戦いの定義 defined の、人（human_side）と CPU の対戦設定。人の編成は渡したもの。
## CPU の側の部隊を戦いの定義が決め打ちにしていれば（ストーリーの話の敵）、CPU の編成は作らない（対戦には決め打ちの部隊が出る。deck_of）。
## 決め打ちでなければ、CPU の編成は CpuDeck が cpu_army から作る。
## 人と CPU の対戦設定は、どのモードもここを通す（対戦モードは versus_cpu、ストーリーは story_battle.gd）。
static func on_scenario(
	defined: Scenario, with_seed: int, human_side: Unit.Side, human_deck: Deck, cpu_army := UnitKind.Army.NONE,
) -> MatchSetup:
	var setup := _on(defined, with_seed)
	setup.set_human(human_side, human_deck)
	var cpu_side := (1 - human_side) as Unit.Side
	if defined.is_fixed(cpu_side):
		setup.controllers[cpu_side] = Controller.CPU
	else:
		setup.set_cpu(cpu_side, cpu_army)
	return setup


## 人（プレイヤー1 か 2）と CPU の対戦モードの対戦設定。人の編成は渡したもの、CPU の編成は CpuDeck が cpu_army から作る。
static func versus_cpu(
	at_stage: BoardGenerator.Stage, with_seed: int, human_deck: Deck, cpu_army: UnitKind.Army,
	human_side := Unit.Side.PLAYER1,
) -> MatchSetup:
	return on_scenario(Scenario.versus(at_stage), with_seed, human_side, human_deck, cpu_army)


## 戦いの定義 defined の、人どうしの対戦設定（先手の編成 first、後手の編成 second）。
## 人どうしの対戦設定は、どのモードもここを通す（対戦モードの生成のマップは versus_human）。
static func humans_on(defined: Scenario, with_seed: int, first: Deck, second: Deck) -> MatchSetup:
	var setup := _on(defined, with_seed)
	setup.set_human(Unit.Side.PLAYER1, first)
	setup.set_human(Unit.Side.PLAYER2, second)
	return setup


## 人どうしの、対戦モードのマップ at_stage の対戦設定。
static func versus_human(at_stage: BoardGenerator.Stage, with_seed: int, first: Deck, second: Deck) -> MatchSetup:
	return humans_on(Scenario.versus(at_stage), with_seed, first, second)


## 戦いの定義と種だけを入れた設定（どちらを誰が動かすかは、呼ぶ側が入れる）。
static func _on(defined: Scenario, with_seed: int) -> MatchSetup:
	var setup := MatchSetup.new()
	setup.scenario = defined
	setup.battle_seed = with_seed
	return setup


## 軍ごとの既定の編成（予算どおり）。人が編成を組まずに始めるときに使う。CPU の編成（CpuDeck）と同じもの。
static func default_deck(army: UnitKind.Army) -> Deck:
	return CpuDeck.build(army)


## side を人が動かし、その編成を deck にする。
func set_human(side: Unit.Side, deck: Deck) -> void:
	decks[side] = deck
	controllers[side] = Controller.HUMAN


## side を CPU が動かし、その編成を army の CPU の編成（CpuDeck）にする。
func set_cpu(side: Unit.Side, army: UnitKind.Army) -> void:
	decks[side] = CpuDeck.build(army)
	controllers[side] = Controller.CPU


func is_cpu(side: Unit.Side) -> bool:
	return controllers[side] == Controller.CPU


## CPU が動かすプレイヤー番号の並び（小さい順）。
func cpu_sides() -> Array[Unit.Side]:
	var sides: Array[Unit.Side] = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		if is_cpu(side):
			sides.append(side)
	return sides


## side が対戦に出す編成。戦いの定義の決め打ちの部隊があればそれ、無ければ選んだ編成（無ければ null）。
func deck_of(side: Unit.Side) -> Deck:
	return scenario.fixed_decks[side] if scenario.is_fixed(side) else decks[side]


## そのプレイヤーの軍。編成が無ければ Army.NONE。
func army_of(side: Unit.Side) -> UnitKind.Army:
	var deck := deck_of(side)
	return deck.army if deck != null else UnitKind.Army.NONE


## 対戦を始められない理由の一覧。空なら始められる。並びは Problem の順で、同じ理由は 1 回だけ。
func problems() -> Array[Problem]:
	var found: Array[Problem] = []
	var chosen: Array[Deck] = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		if not scenario.is_fixed(side):
			chosen.append(decks[side])
	if chosen.has(null):
		found.append(Problem.NO_DECK)
	if chosen.any(func(deck: Deck) -> bool: return deck != null and not _deck_passes(deck)):
		found.append(Problem.INVALID_DECK)
	if not scenario.can_make_board():
		found.append(Problem.NO_BOARD)
	return found


func is_valid() -> bool:
	return problems().is_empty()


## 盤面を作り、両方の軍を本陣に置いた、始まる前の対戦。始められない設定（problems() が空でない）なら null。
## 戦いの定義を読むのは、ここだけ。設定は変えない。同じ設定から何度でも、同じ対戦を作れる。
func create_battle() -> Battle:
	if not is_valid():
		return null
	var board := scenario.make_board(battle_seed)
	if board == null:
		return null
	if trials.has(TrialRules.BATTERY):
		BoardGenerator.arm_batteries(board)
	if trials.has(TrialRules.STRONGHOLD):
		Stronghold.arm(board, battle_seed)
	var battle := Battle.new(board, battle_seed)
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		var placement: Array[Vector2i] = []
		placement.assign(placements[side])
		var placed := Deployment.deploy(
			battle, side, deck_of(side), scenario.deploy_cells_of(side), placement, scenario.has_king(side)
		)
		_apply_start_growth(placed, scenario.start_growth[side])
		battle.win_conditions[side] = scenario.win_conditions_of(side)
		if board.stronghold_cell != Board.NO_CELL:
			battle.win_conditions[side].append(GameWonEvent.Reason.STRONGHOLD_HELD)
		battle.ult_gauge[side] = scenario.start_gauge[side]
	battle.hold_turns = scenario.hold_turns
	return battle


## 置いた駒 placed（将が先頭、あとは部隊の並びの順）に、始めのレベルと経験値 rows を当てる。
static func _apply_start_growth(placed: Array[Unit], rows: Array) -> void:
	var units := placed.filter(func(unit: Unit) -> bool: return unit.kind != UnitKind.Id.KING)
	for i in mini(units.size(), rows.size()):
		Growth.start_at(units[i], rows[i][0], rows[i][1])


func _deck_passes(deck: Deck) -> bool:
	for problem in deck.problems():
		if not (ignore_budget and problem == Deck.Problem.OVER_BUDGET):
			return false
	return true
