extends SceneTree
## 折り返しの点検: 全部の話の台詞と、画面の文の表（game/text/*.csv）の長い文を、使う所の幅で折り返し（game/text_wrap.gd）、
## 切れ方の悪い所（語の途中で切った所、短すぎる最後の行）と、枠の行の数を超える所を並べる。
##
##     godot --headless --path . -s res://tools/wrap_audit.gd             # 話の台詞と、画面の文の表
##     godot --headless --path . -s res://tools/wrap_audit.gd -- --story  # 話の台詞だけ
##
## 話の台詞で見つかれば、終わりの値を 1 にする（画面の文の表は、使う所の幅が場面で変わるので、決めた幅で見て並べる）。
## 同じものを tests/game/test_wrap_audit.gd が PR ごとの検査で確かめる。

const WrapAudit := preload("res://tools/wrap_audit_lib.gd")


func _init() -> void:
	var story_only := OS.get_cmdline_user_args().has("--story")
	var found := WrapAudit.audit_story()
	for line in found:
		print(line)
	print("話の台詞: %d 行を見て、%d か所" % [WrapAudit.story_lines().size(), found.size()])
	if not story_only:
		var texts := WrapAudit.audit_texts()
		for line in texts:
			print(line)
		print("画面の文の表: %d か所" % texts.size())
	quit(1 if not found.is_empty() else 0)
