class_name Scenario
extends RefCounted
## 戦いの定義（docs/scenario.md）。1 回の戦いの、作り置きの変わらないところ。
## 見た目の名前、盤の出どころ（生成か、手で作ったマップか）、プレイヤーごとの初期位置と決め打ちの部隊と勝ちの条件。
##
## 対戦の設定（MatchSetup）が 1 つ持ち、対戦を作るとき（MatchSetup.create_battle）だけ読む。
## 種、人が選んだ部隊、誰が動かすかは、対戦の設定の側にある（1 回ぶんの選択なので）。
## 添字のある値は、プレイヤー番号（Unit.Side.PLAYER1 = 0、PLAYER2 = 1）ごと。

## 画面に出す名前。
var title := ""
## 盤の出どころ。hand_map があれば、手で作ったマップ（種によらず、いつも同じ盤）。
## 無ければ、ステージ stage を大きさ board_size で生成する。
var hand_map: HandMap = null
var stage := BoardGenerator.Stage.PLAIN
var board_size := BoardGenerator.DEFAULT_SIZE
## プレイヤーごとの、将でない駒を置くマスの列（編成の並びの順に使う）。空なら、いつもの置き方（本陣の前の行）。
## 将はいつも本陣に置く。Deployment.deploy が使う（docs/player-loadout.md）。
var deploy_cells: Array[Array] = [[], []]
## プレイヤーごとの決め打ちの部隊。null なら、対戦の設定で選んだ部隊（MatchSetup.decks）を出す。
## 決め打ちの部隊は、編成の決まりの検査（Deck.problems）を通さずに、書いたとおりに置く（数で押す敵を作れる）。
var fixed_decks: Array[Deck] = [null, null]
## プレイヤーごとの勝ちの条件の列（GameWonEvent.Reason の値。docs/win-conditions.md）。
## 対戦を作るとき、対戦（Battle.win_conditions）へ写す。既定は、どちらも STANDARD_WIN_CONDITIONS。
var win_conditions: Array[Array] = [STANDARD_WIN_CONDITIONS.duplicate(), STANDARD_WIN_CONDITIONS.duplicate()]

## いまの対戦モードの勝ち方: 敵の将を倒す、敵の本陣を占拠し続ける。
const STANDARD_WIN_CONDITIONS: Array[GameWonEvent.Reason] = [
	GameWonEvent.Reason.KING_DEFEATED, GameWonEvent.Reason.HQ_CAPTURED
]


## 対戦モードの、ステージ at_stage の戦いの定義（盤は生成。部隊は両方とも対戦の設定で選ぶ）。
static func versus(at_stage: BoardGenerator.Stage) -> Scenario:
	var scenario := Scenario.new()
	scenario.title = MatchSetup.stage_name(at_stage)
	scenario.stage = at_stage
	return scenario


## 手で作ったマップ map の戦いの定義（部隊は両方とも対戦の設定で選ぶ。初期位置はいつもの置き方）。
static func on_map(map: HandMap, map_title: String) -> Scenario:
	var scenario := Scenario.new()
	scenario.title = map_title
	scenario.hand_map = map
	return scenario


## side の部隊を、決め打ちの deck にする。
func fix_deck(side: Unit.Side, deck: Deck) -> void:
	fixed_decks[side] = deck


func is_fixed(side: Unit.Side) -> bool:
	return fixed_decks[side] != null


## side の将でない駒を置くマスの列を cells にする。
func set_deploy_cells(side: Unit.Side, cells: Array[Vector2i]) -> void:
	deploy_cells[side] = cells


## side の将でない駒を置くマスの列（空なら、いつもの置き方）。
func deploy_cells_of(side: Unit.Side) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(deploy_cells[side])
	return cells


## side の勝ちの条件の列を conditions にする。
func set_win_conditions(side: Unit.Side, conditions: Array[GameWonEvent.Reason]) -> void:
	win_conditions[side] = conditions.duplicate()


## side の勝ちの条件の列（写し）。
func win_conditions_of(side: Unit.Side) -> Array[GameWonEvent.Reason]:
	var conditions: Array[GameWonEvent.Reason] = []
	conditions.assign(win_conditions[side])
	return conditions


## 盤を作れるか（手で作ったマップなら HandMap.is_valid()、生成なら大きさが BoardGenerator.MIN_SIZE 以上か）。
func can_make_board() -> bool:
	if hand_map != null:
		return hand_map.is_valid()
	return board_size.x >= BoardGenerator.MIN_SIZE.x and board_size.y >= BoardGenerator.MIN_SIZE.y


## 種 board_seed の盤。作れなければ null。手で作ったマップは種を使わない。
func make_board(board_seed: int) -> Board:
	if not can_make_board():
		return null
	if hand_map != null:
		return hand_map.make_board()
	return BoardGenerator.generate(stage, board_seed, board_size)
