extends SceneTree
## tests/ の下の test_*.gd をすべて実行する。1 つでも失敗したら終了コード 1。
##
##   godot --headless --path . -s res://tools/run_tests.gd
##
## テストの途中でスクリプトのエラー（null の参照など）が起きた場合も失敗にする。
## その場合 GDScript はメソッドを途中で抜けるだけなので、ログを横取りして数える。

const TEST_ROOT := "res://tests"


class ErrorCounter:
	extends Logger

	var count := 0

	func _log_error(
		_function: String, _file: String, _line: int, _code: String, _rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type != ERROR_TYPE_WARNING:
			count += 1

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	var errors := ErrorCounter.new()
	OS.add_logger(errors)

	var passed := 0
	var failed: Array[String] = []
	for path in _find_tests(TEST_ROOT):
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failed.append("%s: 読み込めない" % path)
			continue
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var errors_before := errors.count
			var test: Object = script.new()
			test.call(name)
			var problems: Array[String] = test.failures.duplicate()
			if errors.count != errors_before:
				problems.append("スクリプトのエラーで途中で止まった（上のログを見る）")
			if problems.is_empty():
				passed += 1
			else:
				failed.append("%s %s\n    %s" % [path.get_file(), name, "\n    ".join(problems)])

	OS.remove_logger(errors)
	for line in failed:
		printerr("FAIL ", line)
	print("tests: %d passed, %d failed" % [passed, failed.size()])
	quit(1 if failed.size() > 0 or passed == 0 else 0)


func _find_tests(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		found.append_array(_find_tests(dir_path.path_join(sub)))
	found.sort()
	return found
