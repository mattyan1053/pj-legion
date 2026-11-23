class_name Scenario
extends RefCounted
## 戦いの定義（docs/scenario.md）。1 回の戦いの、作り置きの変わらないところ。
## 見た目の名前、盤の出どころ（生成か、手で作ったマップか）、プレイヤーごとの初期位置と決め打ちの部隊と勝ちの条件。
##
## 対戦設定（MatchSetup）が 1 つ持ち、対戦を作るとき（MatchSetup.create_battle）だけ読む。
## 種、人が選んだ部隊、誰が動かすかは、対戦設定の側にある（1 回ぶんの選択なので）。
## 添字のある値は、プレイヤー番号（Unit.Side.PLAYER1 = 0、PLAYER2 = 1）ごと。

## 画面に出す名前（手で作ったマップの名前。生成のマップは空で、画面が stage から名前を引く。game/names.gd の stage）。
var title := ""
## 盤の出どころ。hand_map があれば、手で作ったマップ（種によらず、いつも同じ盤）。
## 無ければ、マップ stage を大きさ board_size で生成する。
var hand_map: HandMap = null
## 対戦モードの戦いか（手で作ったマップの、対戦モードだけの物を置くか。HandMap.make_board の for_versus）。
var for_versus := false
var stage := BoardGenerator.Stage.PLAIN
var board_size := BoardGenerator.DEFAULT_SIZE
## プレイヤーごとの、将でない駒を置くマスの列（編成の並びの順に使う）。空なら、いつもの置き方（本陣の前の行）。
## 将はいつも本陣に置く。Deployment.deploy が使う（docs/player-loadout.md）。
var deploy_cells: Array[Array] = [[], []]
## プレイヤーごとの決め打ちの部隊。null なら、対戦設定で選んだ部隊（MatchSetup.decks）を出す。
## 決め打ちの部隊は、編成の決まりの検査（Deck.problems）を通さずに、書いたとおりに置く（数で押す敵を作れる）。
var fixed_decks: Array[Deck] = [null, null]
## プレイヤーごとの、将を置くか。偽なら、その陣営は将のいない群れ（本陣は空のまま。将の撃破では負けない）。
## ストーリーの話の敵だけが使う（対戦モードはいつも真）。対戦を作るとき、Deployment.deploy に渡す。
var kings: Array[bool] = [true, true]
## プレイヤーごとの勝ちの条件の列（GameWonEvent.Reason の値。docs/win-conditions.md）。
## 対戦を作るとき、対戦（Battle.win_conditions）へ写す。既定は、どちらも STANDARD_WIN_CONDITIONS。
var win_conditions: Array[Array] = [STANDARD_WIN_CONDITIONS.duplicate(), STANDARD_WIN_CONDITIONS.duplicate()]
## 「守り切る」（GameWonEvent.Reason.TURNS_HELD）のターン数。このターンが終わるまで決着しなければ、守り切る側の勝ち。
## 0 なら守り切るは働かない。対戦を作るとき、対戦（Battle.hold_turns）へ写す。
var hold_turns := 0
## プレイヤーごとの、対戦の始めの必殺技のゲージ（0 から Ults.GAUGE_MAX。docs/tactical-ult.md）。
## 対戦モードの定義（versus、on_map）は、先手だけ Ults.FIRST_PLAYER_START_GAUGE から（いまは 0）。
## 対戦を作るとき、対戦（Battle.ult_gauge）へ写す。ストーリーの話は、話の start_gauge で置き換える（ふつうは 0）。
var start_gauge: Array[int] = [0, 0]
## プレイヤーごとの、駒の始めのレベルと経験値（[レベル, 経験値] の列。部隊の並びの順に、将でない駒へ当てる）。
## 列が短ければ、残りの駒はいつもどおり（レベル 1、経験値 0）。既定は、どちらも空。
## 対戦を作るとき、置いた駒へ写す（Growth.start_at）。進化の選び方を教える話が、あと少しで進化する駒から始めるのに使う。
var start_growth: Array[Array] = [[], []]

## この戦いに、いつも付く縫い目の様子（Seam.Sign の並び。docs/seam-signs.md）。ストーリーの話のファイルが指定する。
## 空なら、対戦設定の決まり（OptionalRules.SEAM。対戦モードのランダム）に任せる。対戦を作るとき、対戦（Battle.signs）へ写す。
var signs: Array[int] = []

## いまの対戦モードの勝ち方: 敵の将を倒す、敵の本陣を占拠し続ける。
const STANDARD_WIN_CONDITIONS: Array[GameWonEvent.Reason] = [
	GameWonEvent.Reason.KING_DEFEATED, GameWonEvent.Reason.HQ_CAPTURED
]


## 対戦モードの、マップ at_stage の戦いの定義（盤は生成。部隊は両方とも対戦設定で選ぶ）。
static func versus(at_stage: BoardGenerator.Stage) -> Scenario:
	var scenario := Scenario.new()
	scenario.stage = at_stage
	scenario.start_gauge[Unit.Side.PLAYER1] = Ults.FIRST_PLAYER_START_GAUGE
	return scenario


## 手で作ったマップ map の戦いの定義（部隊は両方とも対戦設定で選ぶ。初期位置はいつもの置き方）。
## in_versus なら対戦モードの戦い（マップの、対戦モードだけの物も置く）。ストーリーの話は偽のまま使う。
static func on_map(map: HandMap, map_title: String, in_versus := false) -> Scenario:
	var scenario := Scenario.new()
	scenario.title = map_title
	scenario.hand_map = map
	scenario.for_versus = in_versus
	scenario.start_gauge[Unit.Side.PLAYER1] = Ults.FIRST_PLAYER_START_GAUGE
	return scenario


## side の部隊を、決め打ちの deck にする。
func fix_deck(side: Unit.Side, deck: Deck) -> void:
	fixed_decks[side] = deck


func is_fixed(side: Unit.Side) -> bool:
	return fixed_decks[side] != null


## side を将のいない群れにする（将を置かない）。
func remove_king(side: Unit.Side) -> void:
	kings[side] = false


func has_king(side: Unit.Side) -> bool:
	return kings[side]


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


## side を「守る側」にする: turns ターンが終わるまで決着しなければ勝ち。将の撃破と本陣の占拠でも勝てる。
## 相手（攻める側）の勝ちの条件は変えない。
func hold_for(side: Unit.Side, turns: int) -> void:
	var conditions := STANDARD_WIN_CONDITIONS.duplicate()
	conditions.append(GameWonEvent.Reason.TURNS_HELD)
	set_win_conditions(side, conditions)
	hold_turns = turns


## side の、対戦の始めの必殺技のゲージを amount にする（0 から Ults.GAUGE_MAX に収める）。
func set_start_gauge(side: Unit.Side, amount: int) -> void:
	start_gauge[side] = clampi(amount, 0, Ults.GAUGE_MAX)


## side の駒の始めのレベルと経験値を rows（[レベル, 経験値] の列。部隊の並びの順）にする。
## 値は Growth.start_at と同じに収める（レベルは 1 から Growth.MAX_LEVEL - 1、経験値は 0 から Growth.EXPERIENCE_PER_LEVEL - 1）。
func set_start_growth(side: Unit.Side, rows: Array) -> void:
	var kept: Array = []
	for row: Array in rows:
		kept.append([Growth.start_level(row[0]), Growth.start_experience(row[1])])
	start_growth[side] = kept


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
		return hand_map.make_board(for_versus)
	return BoardGenerator.generate(stage, board_seed, board_size)
