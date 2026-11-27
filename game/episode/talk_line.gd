extends RefCounted
## 会話の 1 行（話のファイルの [before]・[after]・[lost] の 1 行と、[cues] の台詞の中身）。ノードに依存しない。
## 読む側は、欄を名前で読む（kind・side・text・who）。並びの位置で読まない。
##
## 行の種類を足すときは、Kind に足し、作る関数（speech・narration のような）を 1 つ足す。
## 選択肢は、行の種類ではなく、行に付くもの: 問いの行（選ばせる前の最後の行）が choice と options を持ち、
## 答えごとの行と「(if 名前 = 答え)」の行が、出す条件（when_choice・when_answer・when_not）を持つ（docs/story.md の「選択肢」）。
## 文に差し込むもの（主人公の名前など）は shown_text に足す。文を画面・道具へ出す所は、どこも shown_text を通す。

## 行の種類。
enum Kind {
	SPEECH,  ## 話し手の台詞（「話し手: 文」）
	NARRATION,  ## 地の文（「> 文」。話し手がいない）
}

## 地の文の行の陣営（話し手の陣営 0・1 と重ならない番号。会話の場面とログは、この番号で地の文と見る）。
const NARRATION_SIDE := 3
const TalkLine := preload("res://game/episode/talk_line.gd")

var kind := Kind.SPEECH
## 話し手の陣営（0 = 人の軍、1 = 敵の軍）。地の文は NARRATION_SIDE。
var side := 0
## 文（話のファイルに書いたまま）。
var text := ""
## 話し手（話の speakers の番号）。地の文は -1。
var who := -1


## この行のあとに選ばせる選択肢の名前（答えを覚える名前。無ければ空）と、答えの列（{"key": 答えの鍵, "text": 画面の文}。2〜3 つ）。
var choice := &""
var options: Array[Dictionary] = []
## この行を出す条件（無ければ when_choice が空 = いつも出す）: 選択肢 when_choice の答えが when_answer のとき（when_not なら、そうでないとき）。
var when_choice := &""
var when_answer := &""
var when_not := false


## 選ばせる行か。
func asks() -> bool:
	return choice != &""


## この行を出すか。answer_of は「選択肢の名前 → 覚えている答えの鍵（まだ選んでいなければ空）」を返す関数。
func holds(answer_of: Callable) -> bool:
	if when_choice == &"":
		return true
	return (StringName(answer_of.call(when_choice)) == when_answer) != when_not


## 話し手 who（陣営 side）の台詞 said。
static func speech(speaker_side: int, said: String, speaker: int) -> TalkLine:
	var line := TalkLine.new()
	line.kind = Kind.SPEECH
	line.side = speaker_side
	line.text = said
	line.who = speaker
	return line


## 地の文 told。
static func narration(told: String) -> TalkLine:
	var line := TalkLine.new()
	line.kind = Kind.NARRATION
	line.side = NARRATION_SIDE
	line.text = told
	line.who = -1
	return line


func is_narration() -> bool:
	return kind == Kind.NARRATION


## 話し手の名前（speakers は話の speakers）。地の文と、番号の外は空。
func speaker_in(speakers: Array) -> String:
	return speakers[who] if who >= 0 and who < speakers.size() else ""


## 画面に出す文。いまは書いたまま（名前の差し込みなどは、ここに足す）。
func shown_text() -> String:
	return text


## 比べる・控えるための形（テスト用。読む側はこれを使わず、欄を名前で読む）。
func as_dict() -> Dictionary:
	var found := {"kind": kind, "side": side, "text": text, "who": who}
	if asks():
		found["choice"] = choice
		found["options"] = options
	if when_choice != &"":
		found["when"] = [when_choice, when_answer, when_not]
	return found


func _to_string() -> String:
	return str(as_dict())
