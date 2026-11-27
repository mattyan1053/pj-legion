extends RefCounted
## 会話の 1 行（話のファイルの [before]・[after]・[lost] の 1 行と、[cues] の台詞の中身）。ノードに依存しない。
## 読む側は、欄を名前で読む（kind・side・text・who）。並びの位置で読まない。
##
## 行の種類を足すとき（選択肢の行など）は、Kind に足し、作る関数（speech・narration のような）を 1 つ足す。
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
	return {"kind": kind, "side": side, "text": text, "who": who}


func _to_string() -> String:
	return str(as_dict())
