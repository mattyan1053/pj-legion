extends RefCounted
## 対戦の途中の会話（docs/story.md の「対戦の途中の会話」）。話のファイルの [cues]（いつ・だれが・何と言うか）を持ち、
## 行動ごとに、ルールが返した出来事の列（BattleEvent）と盤の状態から、いま出す台詞を選ぶ。ノードに依存しない。
##
## ルール（rules/）には入れない。台詞は勝ち負けに関わらないので、画面の側だけで見る。
## どの台詞も、1 回の対戦で 1 度だけ出す（「同じマップで再戦」で作り直せば、また出る）。
## 決着した行動のあとは、何も出さない（決着の画面と重ねない）。

## きっかけ（[cues] の行の先頭）。
const TURN := &"turn"  ## 値 = ターン N。人の番（プレイヤー1 のフェーズ）の始め
const KING_HALF := &"king_half"  ## 値 = 陣営（0 か 1）。その陣営の将の HP が半分を切った
const FALLEN := &"fallen"  ## 値 = 陣営（0 か 1）。その陣営の駒（将を除く）が初めて倒れた
const ULT_READY := &"ult_ready"  ## 値 = 陣営（0 か 1）。その陣営の必殺技のゲージがたまった（UltReadyEvent）
const RELIC := &"relic"  ## 値 = 陣営（0 か 1）。その陣営が聖遺物を受け取った（中ボスを倒した。RelicGainedEvent）
const KINDS: Array[StringName] = [TURN, KING_HALF, FALLEN, ULT_READY, RELIC]
const TalkCue := preload("res://game/episode/talk_cue.gd")


## 出す台詞 1 つ。
class Line:
	extends RefCounted
	var side: int
	var name: String
	var text: String
	## 話し手の姿（{"kind": 駒の種類, "evolved": 進化後か}。episode.gd の figures）。空なら、アイコンを出さない。
	var figure: Dictionary

	func _init(side_: int, name_: String, text_: String, figure_ := {}) -> void:
		side = side_
		name = name_
		text = text_
		figure = figure_


## 途中の台詞（game/episode/talk_cue.gd。きっかけ・値・会話の行）の列。
var _cues: Array[TalkCue] = []
## 話し手の名前（0 = 人の軍の主な話し手、1 = 敵の軍の主な話し手、2 から = ほかの話し手。episode.gd の speakers）。
var _names: Array = []
## 話し手の姿（_names と同じ並び。episode.gd の figures）。
var _figures: Array = []
## 遊ぶ人の付けた主人公の名前（空なら既定の名前。game/hero_name.gd）。
var hero := ""
## 出した台詞（[cues] の何番目か）。
var _said := {}


func _init(cues: Array[TalkCue] = [], speakers: Array = [], figures: Array = [], hero_name := "") -> void:
	_cues = cues
	_names = speakers
	_figures = figures
	hero = hero_name


## 会話の行 talk（game/episode/talk_line.gd）を、出す台詞に。speakers・figures は話の speakers・figures。
## named は、遊ぶ人の付けた主人公の名前（空なら既定の名前）。
static func line_of(talk: TalkCue.TalkLine, speakers: Array, figures: Array, named := "") -> Line:
	var who := talk.who
	return Line.new(talk.side, talk.speaker_in(speakers, named), talk.shown_text(named), figures[who] if who >= 0 and who < figures.size() else {})


func is_empty() -> bool:
	return _cues.is_empty()


## 対戦の始めに出す台詞（ターン 1 の人の番の始め）。
func on_start(battle: Battle) -> Array[Line]:
	return _take(battle, [], true)


## 行動 1 つのあとに出す台詞。events はその行動でルールが返した出来事の列。
func on_events(battle: Battle, events: Array[BattleEvent]) -> Array[Line]:
	return _take(battle, events, false)


func _take(battle: Battle, events: Array[BattleEvent], at_start: bool) -> Array[Line]:
	var lines: Array[Line] = []
	if battle == null or battle.is_over():
		return lines
	for i in _cues.size():
		if _said.has(i):
			continue
		var cue := _cues[i]
		if _fires(battle, events, at_start, cue.trigger, cue.value):
			_said[i] = true
			lines.append(line_of(cue.line, _names, _figures, hero))
	return lines


func _fires(battle: Battle, events: Array[BattleEvent], at_start: bool, kind: StringName, value: int) -> bool:
	match kind:
		TURN:
			if at_start:
				return battle.turn == value and battle.phase == Unit.Side.PLAYER1
			return events.any(func(e: BattleEvent) -> bool:
				return e is PhaseStartedEvent and e.turn == value and e.side == Unit.Side.PLAYER1)
		KING_HALF:
			for unit in battle.units:
				if unit.kind == UnitKind.Id.KING and unit.side == value:
					return unit.hp * 2 < unit.max_hp()
			return false
		FALLEN:
			return events.any(func(e: BattleEvent) -> bool:
				return e is UnitDefeatedEvent and e.side == value and e.kind != UnitKind.Id.KING)
		ULT_READY:
			return events.any(func(e: BattleEvent) -> bool: return e is UltReadyEvent and e.side == value)
		RELIC:
			return events.any(func(e: BattleEvent) -> bool: return e is RelicGainedEvent and e.side == value)
	return false
