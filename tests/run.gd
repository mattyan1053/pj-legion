extends SceneTree
## `tests/` の下の `test_*.gd` をすべて探して実行する。一覧は持たない（置けば拾われる）。
##
##   godot --headless --path . --script res://tests/run.gd
##
## 失敗が 1 つでもあれば終了コード 1 で終わる。

const ROOT := "res://tests"
const TestCase := preload("res://tests/test_case.gd")


## テストの途中で出たエンジンのエラー（実行時エラー、push_error）を数える。
## 実行時エラーはメソッドを黙って打ち切るので、数えないと成功に見えてしまう。
class ErrorCounter:
	extends Logger
	var count := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			count += 1


func _initialize() -> void:
	var errors := ErrorCounter.new()
	OS.add_logger(errors)
	var files := _find_test_files(ROOT)
	files.sort()
	var ran := 0
	var failed := 0
	for path in files:
		var script: Variant = load(path)
		if not (script is GDScript and script.can_instantiate()):
			print("FAIL %s: 読み込めない" % path)
			failed += 1
			continue
		var names := _test_method_names(script)
		if names.is_empty() or not (script.new() is TestCase):
			print("FAIL %s: test_case.gd を継承した test_ メソッドが無い" % path)
			failed += 1
			continue
		for method in names:
			var case: TestCase = script.new()
			var errors_before := errors.count
			case.call(method)
			ran += 1
			if errors.count > errors_before:
				case.failures.append("実行中にエラーが出た（上のログを見る）")
			if not case.failures.is_empty():
				failed += 1
				for failure in case.failures:
					print("FAIL %s %s: %s" % [path.trim_prefix(ROOT + "/"), method, failure])
	print("tests: %d 件中 %d 件が失敗" % [ran, failed])
	quit(1 if failed > 0 or ran == 0 else 0)


func _find_test_files(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for dir_name in DirAccess.get_directories_at(dir_path):
		found.append_array(_find_test_files(dir_path.path_join(dir_name)))
	for file_name in DirAccess.get_files_at(dir_path):
		if file_name.begins_with("test_") and file_name.ends_with(".gd") and file_name != "test_case.gd":
			found.append(dir_path.path_join(file_name))
	return found


func _test_method_names(script: GDScript) -> PackedStringArray:
	var names: PackedStringArray = []
	for method in script.get_script_method_list():
		if method.name.begins_with("test_") and not names.has(method.name):
			names.append(method.name)
	return names
