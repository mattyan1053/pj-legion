extends RefCounted
## 対戦の途中の台詞 1 つ（話のファイルの [cues] の 1 行「(きっかけ 値) 話し手: 文」）。ノードに依存しない。
## いつ出すか（trigger・value。battle_cues.gd の KINDS）と、何を言うか（line。talk_line.gd）。読む側は欄を名前で読む。

const TalkLine := preload("res://game/episode/talk_line.gd")

## きっかけ（battle_cues.gd の TURN・KING_HALF など）。
var trigger := &""
## きっかけの値（TURN はターン、ほかは陣営）。
var value := 0
## 言うこと（地の文にはならない）。
var line: TalkLine


func _init(cue_trigger := &"", cue_value := 0, cue_line: TalkLine = null) -> void:
	trigger = cue_trigger
	value = cue_value
	line = cue_line


## 比べる・控えるための形（テスト用）。
func as_dict() -> Dictionary:
	return {"trigger": trigger, "value": value, "line": line.as_dict() if line != null else {}}


func _to_string() -> String:
	return str(as_dict())
