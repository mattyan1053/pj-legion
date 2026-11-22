extends SceneTree
## 全部の話の台詞を、呼び方と一人称の表（game/story/voices.txt）に掛けて、外れた所を並べる（tools/voice_check.gd）。
##
##   godot --headless --path . -s res://tools/voice_report.gd

const VoiceCheck := preload("res://tools/voice_check.gd")


func _initialize() -> void:
	var table: VoiceCheck = VoiceCheck.load_table()
	for problem: String in table.problems:
		printerr("voice: %s" % problem)
	var found: PackedStringArray = table.check_all()
	for line: String in found:
		print("voice: %s" % line)
	print("voice: %d 件" % found.size())
	quit(0 if found.is_empty() and table.problems.is_empty() else 1)
