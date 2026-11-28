extends "res://game/talk_screen/talk_naming.gd"
## 会話の場面の、盤のカットシーン（渡された会話に "cut_board" がある。docs/story.md の「盤のカットシーン」）の部品:
## 背景の舞台（cut_stage.gd。台本の兵が盤の上で動く）と、出来事の塊（"beats"。[i] は i 番目の文の前、最後は最後の文のあと）。
## 再生と文は交互に回す（talk_screen.gd の _go_to_line）。塊を再生している間は、文の枠と名前の札を消し、文を進めない。

const CutStage := preload("res://game/cut_stage.gd")

## 舞台（盤のカットシーンでなければ null）。
var _cut_stage: CutStage
## 出来事の塊（talk の "beats"）。
var _beats: Array = []
## 再生し終えた塊の数（次に再生する塊の番号）。
var _beat_at := 0
## いま再生している塊の番号（再生していなければ -1）。
var _beat_playing := -1
## スキップした（残りを終わりの盤まで済ませている）。
var _board_skipped := false
## スキップが、残りを終わりの盤まで済ませ終えた（このあとの「次へ」「スキップ」は、終わり方へ回す）。
var _board_finished := false
## 文の枠（盤のカットシーンでは、塊を再生している間だけ消す）。
var _box: Control


## 盤のカットシーンか。
func is_board_cut() -> bool:
	return talk.has("cut_board")


## 塊を再生している途中か（検査用）。
func is_beat_playing() -> bool:
	return _beat_playing >= 0


## 舞台（検査用）。
func cut_stage() -> CutStage:
	return _cut_stage


func _make_cut_stage() -> void:
	_beats = talk.get("beats", [])
	_cut_stage = CutStage.new(talk["cut_board"], talk.get("look", &""), talk.get("looks", {}), context.play_sound)
	add_child(_cut_stage)


## 文の枠・名前の札・下の案内を、出すか消すか（大きさと場所は変えない）。
func _set_text_shown(shown: bool) -> void:
	if not shown and _cut_stage != null:
		_cut_stage.show_speaker("")  # 兵が動いている間は、話し手の印も出さない
	for part: CanvasItem in [_box, _plate, _hint]:
		if part != null:
			part.self_modulate.a = 1.0 if shown else 0.0
			for child in part.get_children():
				if child is CanvasItem:
					(child as CanvasItem).modulate.a = 1.0 if shown else 0.0


## index 番目の文の前に再生する塊（無ければ空）。
func _beat_before(index: int) -> Array:
	return _beats[index] if index < _beats.size() else []


## 文 index のすぐ前に、盤の動きがあるか（あれば、右クリックで index の前の文へは戻れない。盤は戻せないので）。
func _moves_before(index: int) -> bool:
	return is_board_cut() and not _beat_before(index).is_empty()


## まだ見せていない塊の出来事（スキップで済ませるもの）。再生の途中の塊は、再生が自分で済ませるので入れない。
func _unplayed_events() -> Array:
	var rest: Array = []
	var from := _beat_playing + 1 if _beat_playing >= 0 else _beat_at
	for i in range(from, _beats.size()):
		rest.append_array(_beats[i])
	return rest


## ログ: 塊を再生している間は、その塊より前の文まで。
func _log_lines() -> Array:
	var rows := super()
	if _beat_playing >= 0:
		return rows.slice(0, _beat_playing)
	return rows
