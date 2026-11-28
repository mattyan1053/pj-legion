extends RefCounted
## 会話の場面（talk_screen.gd）に渡すもの 1 つ（docs/story.md の「会話の場面に渡すもの」）。ノードに依存しない。
## 作るのは話の流れ（story.gd の run_of・talk_of）。読むのは会話の場面（talk_screen.gd と game/talk_screen/）、ログ（talk_log.gd）、
## 撮る道具（tools/shots/）、点検（game/autoplay/）、テスト。どれも欄の名前で読む（打ち間違いは読み込みで落ちる）。
##
## 場面の型（shape）は 1 つの値。型で、背景と出すものが決まる:
## | 型 | 背景 | 見出し・話し手の姿・文の枠 | 読む欄 |
## | MAP | 話の盤（board・look）。対戦のある話なら駒（battle・after） | 出す | battle、after |
## | PLACE | 別の場所の景色（board・look。兵は立たせない） | 出す | |
## | CUT | 景色（board・look）か、色の幕（color） | 出さない（文だけを真ん中に） | color |
## | BOARD_CUT | 台本の盤（cut_board。兵が動く） | 見出しと姿は出さない | cut_board、beats、looks |
## 型を足したら、型を読む所（tests/game/test_talk_shapes.gd の READERS）の全部で、その型を扱う。扱わないと、そのテストが落ちる。

const TalkScene := preload("res://game/talk_scene.gd")

## 場面の型。
enum Shape {
	MAP,  ## 盤の前の会話（背景は話の盤。対戦のある話なら駒が立つ）
	PLACE,  ## 別の場所の会話（背景はその場所の景色。兵は立たせない）
	CUT,  ## 地の文のカットシーン（文の枠も話し手も出さず、背景の上に文）
	BOARD_CUT,  ## 盤のカットシーン（背景は台本の盤で、台本の兵だけが立って動く）
}

## 会話の行の、知らせ（話し手の名前の札を金の縁にする。「飛ばす」でも飛ばさない）と、地の文（話し手のいない行）の side。
const NOTICE_SIDE := 2
const NARRATION_SIDE := 3
## Line の who を書かなかったとき（陣営の番号を、話し手の番号にする）。
const WHO_OF_SIDE := -2


## 選択肢の答え 1 つ。
class Option:
	extends RefCounted
	## 答えの鍵（記録に書く。あとの行の (if 名前 = 鍵) が読む）。
	var key := &""
	## 出す文（主人公の名前を入れたもの）と、書いたままの文（名前が話の途中で決まったら、ここから作り直す）。
	var text := ""
	var raw := ""

	func _init(answer_key: StringName = &"", shown := "", written := "") -> void:
		key = answer_key
		text = shown
		raw = written if written != "" else shown


## 行のあとに選ばせる選択肢（docs/story.md の「選択肢」）。
class Choice:
	extends RefCounted
	var name := &""
	var options: Array[Option] = []

	func _init(choice_name: StringName = &"", answers: Array[Option] = []) -> void:
		name = choice_name
		options = answers


## 行を出す条件: 選択肢 choice で answer を選んでいる（not なら、選んでいない）。
class When:
	extends RefCounted
	var choice := &""
	var answer := &""
	var negated := false

	func _init(on_choice: StringName = &"", on_answer: StringName = &"", is_not := false) -> void:
		choice = on_choice
		answer = on_answer
		negated = is_not

	## 選んだ答え chosen（まだ選んでいなければ空）で、この行を出すか。
	func holds(chosen: String) -> bool:
		return (chosen == String(answer)) != negated


## 会話の行 1 つ。
class Line:
	extends RefCounted
	## 0 = 人の軍、1 = 敵の軍、NOTICE_SIDE = 知らせ、NARRATION_SIDE = 地の文。
	var side := 0
	## 話し手の番号（会話の figures の並び。地の文・知らせは -1）。
	var who := 0
	## 話し手の名前（地の文は空）と、出す文。
	var name := ""
	var text := ""
	## 書いたままの文（主人公の名前の印を含む行だけ。名前が話の途中で決まったら、ここから作り直す）。
	var raw := ""
	## 主人公が話す行か（名前が決まったら、話し手の名前を入れ直す）。
	var hero_line := false
	## この行のあとで、主人公の名前を聞くか（talk_screen/talk_naming.gd）。
	var naming := false
	## この行のあとに選ばせる選択肢（無ければ null）と、この行を出す条件（無ければ null）。
	var choice: Choice
	var when: When
	## 知らせの行の、文の左に出すアイコン: 駒の種類（UnitKind.Id）、持ち物（Equipment.Id）、軍略（Traits.Id）。無ければ -1。
	var unit_kind := -1
	var item := -1
	var troop_trait := -1

	func _init(line_side := 0, speaker := "", said := "", number := WHO_OF_SIDE) -> void:
		side = line_side
		name = speaker
		text = said
		who = line_side if number == WHO_OF_SIDE else number

	## 選ばせる行か。
	func asks() -> bool:
		return choice != null and not choice.options.is_empty()

	## 地の文か。
	func is_narration() -> bool:
		return side == NARRATION_SIDE

	## 知らせの行か。
	func is_notice() -> bool:
		return side == NOTICE_SIDE

	## 文の左にアイコンを出すか（知らせの、駒・持ち物・軍略）。
	func has_icon() -> bool:
		return unit_kind >= 0 or item >= 0 or troop_trait >= 0

	## 話し手の番号（知らせの行は -1）。
	func speaker_no() -> int:
		return -1 if side >= NOTICE_SIDE else who


var shape := Shape.MAP
## 見出し（話の題。MAP・PLACE だけが出す）。
var title := ""
var lines: Array[Line] = []
## 背景の盤（話のマップか、別の場所のマップ）と、その見た目。盤のカットシーンでは、台本の盤の見た目。
var board: Board
var look := &""
## 曲（空なら場面の表の曲）。
var music := &""
## 話し手の姿（Line の who の番号の並び。episode.gd の figures）。
var figures: Array[Dictionary] = []
## 話の主人公の、既定の名前（主人公のいない話は空。名前が決まったら、行の文と札を入れ直す）。
var hero := ""
## MAP: 話の対戦（story_battle.gd。背景の盤に駒を立たせる。対戦の無い話は null）と、場面の列で対戦のあとの会話か（決着したときの駒を立たせる）。
var battle: RefCounted
var after := false
## CUT: 背景を景色でなく色の幕にするなら、その名前（story_scene.gd の COLORS。空なら景色）。
var color := &""
## BOARD_CUT: 読んだ台本（cut_script.gd）、出来事の塊（[i] は lines[i] の前。最後は最後の文のあと）、話し手の名前 -> 人物の形。
var cut_board: RefCounted
var beats: Array = []
var looks := {}
## 話の最後の会話か（クリアで増えるものの知らせと、行き先の選択は、この場面に出す）と、そのときの次の話
## （「次の話へ」を選ばせる。物語の最後の話なら null）。
var closes := false
var next_episode: RefCounted
## 読み終えたらクリアにする話の id（対戦の無い話の最後の会話。ほかは空）。
var clears := &""


## 型が shape の、見出し title の場面。
static func make(scene_shape: Shape, heading := "") -> TalkScene:
	var scene := TalkScene.new()
	scene.shape = scene_shape
	scene.title = heading
	return scene


## 見出しと話し手の姿を出す型か（カットシーンと盤のカットシーンは出さない）。
func shows_speakers() -> bool:
	return shape == Shape.MAP or shape == Shape.PLACE
