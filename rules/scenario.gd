class_name Scenario
extends RefCounted
## 戦いの定義（docs/scenario.md）。1 回の戦いの、作り置きの変わらないところ。
## 見た目の名前、盤の出どころ、プレイヤーごとの決め打ちの部隊。
##
## 対戦の設定（MatchSetup）が 1 つ持ち、対戦を作るとき（MatchSetup.create_battle）だけ読む。
## 種、人が選んだ部隊、誰が動かすかは、対戦の設定の側にある（1 回ぶんの選択なので）。
## 添字のある値は、プレイヤー番号（Unit.Side.PLAYER1 = 0、PLAYER2 = 1）ごと。

## 画面に出す名前。
var title := ""
## 盤の出どころ: 生成するステージと、盤の大きさ。
var stage := BoardGenerator.Stage.PLAIN
var board_size := BoardGenerator.DEFAULT_SIZE
## プレイヤーごとの決め打ちの部隊。null なら、対戦の設定で選んだ部隊（MatchSetup.decks）を出す。
## 決め打ちの部隊は、編成の決まりの検査（Deck.problems）を通さずに、書いたとおりに置く（数で押す敵を作れる）。
var fixed_decks: Array[Deck] = [null, null]


## 対戦モードの、ステージ at_stage の戦いの定義（盤は生成。部隊は両方とも対戦の設定で選ぶ）。
static func versus(at_stage: BoardGenerator.Stage) -> Scenario:
	var scenario := Scenario.new()
	scenario.title = MatchSetup.stage_name(at_stage)
	scenario.stage = at_stage
	return scenario


## side の部隊を、決め打ちの deck にする。
func fix_deck(side: Unit.Side, deck: Deck) -> void:
	fixed_decks[side] = deck


func is_fixed(side: Unit.Side) -> bool:
	return fixed_decks[side] != null


## 盤を作れるか（大きさが BoardGenerator.MIN_SIZE 以上か）。
func can_make_board() -> bool:
	return board_size.x >= BoardGenerator.MIN_SIZE.x and board_size.y >= BoardGenerator.MIN_SIZE.y


## 種 board_seed の盤。作れなければ null。
func make_board(board_seed: int) -> Board:
	if not can_make_board():
		return null
	return BoardGenerator.generate(stage, board_seed, board_size)
