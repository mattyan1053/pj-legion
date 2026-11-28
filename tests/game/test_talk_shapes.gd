extends "res://tests/base_test.gd"
## 会話の場面の型（talk_scene.gd の Shape）と、盤のカットシーンの台本の行（cut_script.gd の COMMANDS）を読む所の見張り
## （docs/story.md の「場面の型を 1 つ足すとき」「台本の行を 1 つ足すとき」）。出来事の読み手の見張り（test_event_readers.gd）と同じ考え方。
## - 型を読む所（READERS）のどれもが、型の全部をコードで名指しする（注記は数えない）。型を足して、どこかで扱い忘れると、ここで落ちる
## - 見本の物語（game/story/_template/）の話の流れに、型の全部が出てくる（作る側が、型の全部を作れる）
## - 台本の行の語の全部に、読む関数（cut_script.gd の _read_<語>。unit は台本の頭の兵）と、書き方の説明（cut_script.gd の頭、docs/battle-view.md）がある

const TalkScene := preload("res://game/talk_scene.gd")
const Story := preload("res://game/story.gd")
const Campaign := preload("res://game/campaign.gd")
const CutScript := preload("res://game/cut_script.gd")

## 会話の場面の型を、型ごとに読み分ける所。
const READERS: Array[String] = [
	"res://game/episode/story_scene.gd",  # 話のファイルの節から、型を決める（talk_shape）
	"res://game/story.gd",  # 型ごとに、会話の場面へ渡す欄を足す（run_of）
	"res://game/talk_screen.gd",  # 型ごとの背景（_ready）
	"res://tools/story_script.gd",  # 台本の見出し（SCENE_HEADINGS）
]
const TEMPLATE := "res://game/story/_template/story.txt"


## ファイル path のコード（注記を除いたもの）が名指しする型の名前。
static func _shapes_named_in(path: String) -> Array[String]:
	var code := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var at := line.find("#")
		code.append(line if at < 0 else line.substr(0, at))
	var names: Array[String] = []
	for found in RegEx.create_from_string("\\bShape\\.([A-Z_]+)\\b").search_all("\n".join(code)):
		if not names.has(found.get_string(1)):
			names.append(found.get_string(1))
	return names


func test_every_reader_handles_every_talk_shape() -> void:
	var shapes: Array = TalkScene.Shape.keys()
	assert_true(shapes.size() >= 4, "型を見つけられていない")
	for path in READERS:
		var named := _shapes_named_in(path)
		for shape: String in shapes:
			assert_true(named.has(shape), "%s: 会話の場面の型 %s を扱っていない（docs/story.md の「場面の型を 1 つ足すとき」）" % [path.get_file(), shape])
		for name in named:
			assert_true(shapes.has(name), "%s: 知らない型 %s" % [path.get_file(), name])


func test_the_template_story_makes_every_talk_shape() -> void:
	var made := {}
	for episode: RefCounted in Campaign.load_file(TEMPLATE).episodes:
		for data: Variant in Story.run_of(episode, null).all_data():
			if data is TalkScene:
				made[(data as TalkScene).shape] = true
	for shape: String in TalkScene.Shape.keys():
		assert_true(made.has(TalkScene.Shape[shape]), "見本の物語（game/story/_template/）に、型 %s の場面が無い" % shape)


func test_every_script_command_is_read_and_written_down() -> void:
	var source := FileAccess.get_file_as_string("res://game/cut_script.gd")
	var doc := FileAccess.get_file_as_string("res://docs/battle-view.md")
	assert_true(CutScript.COMMANDS.size() >= 10, "台本の行の語を見つけられていない")
	for command: String in CutScript.COMMANDS:
		if command != "unit":  # 台本の頭の兵は、_read が _new_unit で読む
			assert_true(source.contains("func _read_%s(" % command), "cut_script.gd: 台本の行 %s を読む関数（_read_%s）が無い" % [command, command])
		assert_true(source.contains("\n##   %s " % command), "cut_script.gd: 頭の書き方の説明に、台本の行 %s が無い" % command)
		assert_true(doc.contains("`%s`" % command), "docs/battle-view.md: 台本の行 %s の書き方が無い" % command)
