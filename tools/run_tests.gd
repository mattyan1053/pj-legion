extends SceneTree
## tests/ の下の test_*.gd をすべて実行する。1 つでも失敗したら終了コード 1。
##
##   godot --headless --path . -s res://tools/run_tests.gd
##   godot --headless --path . -s res://tools/run_tests.gd -- --full
##
## `test_long_` で始まるメソッドは時間の掛かるもので、長い検査（`-- --full`）のときだけ実行する。
## 長い検査は、テストを分けて並べて回す（tools/check.sh）。そのための絞り込み:
##   -- --long-only                 `test_long_` だけを実行する
##   -- --only=<語>,<語>            「ファイル名 メソッド名」がどれかの語を含むものだけを実行する
##   -- --except=<語>,<語>          どれかの語を含むものを除く
## 終わりに、1 秒以上掛かったテストを、長い順にいくつか出す。
##
## テストの途中でスクリプトのエラー（null の参照など）が起きた場合も失敗にする。
## その場合 GDScript はメソッドを途中で抜けるだけなので、ログを横取りして数える。

const TEST_ROOT := "res://tests"
const LONG_PREFIX := "test_long_"
## 終わりに出す、時間の掛かったテストの数と、出す下限（ミリ秒）。
const SLOW_SHOWN := 8
const SLOW_MSEC := 1000


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

	var args := OS.get_cmdline_user_args()
	var long_only := args.has("--long-only")
	var full := long_only or args.has("--full")
	var only := _list_arg(args, "--only=")
	var except := _list_arg(args, "--except=")
	var passed := 0
	var skipped := 0
	var filtered := 0
	var failed: Array[String] = []
	var timings: Array[Array] = []
	for path in _find_tests(TEST_ROOT):
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failed.append("%s: 読み込めない" % path)
			continue
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var is_long := name.begins_with(LONG_PREFIX)
			if is_long and not full:
				skipped += 1
				continue
			var label := "%s %s" % [path.get_file(), name]
			if (long_only and not is_long) or (not only.is_empty() and not _matches(label, only)) or _matches(label, except):
				filtered += 1
				continue
			var errors_before := errors.count
			var started := Time.get_ticks_msec()
			var test: Object = script.new()
			await test.call(name)  # 画面の大きさを測るテストは、コマを待つ（base_test.gd の settle）
			timings.append([Time.get_ticks_msec() - started, label])
			var problems: Array[String] = test.failures.duplicate()
			if errors.count != errors_before:
				problems.append("スクリプトのエラーで途中で止まった（上のログを見る）")
			if problems.is_empty():
				passed += 1
			else:
				failed.append("%s\n    %s" % [label, "\n    ".join(problems)])

	OS.remove_logger(errors)
	# 時間の掛かったテスト（次に検査が伸びたとき、どこが伸びたか分かるように）。
	timings.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for timing: Array in timings.slice(0, SLOW_SHOWN):
		if timing[0] < SLOW_MSEC:
			break
		print("tests: %5.1f 秒 %s" % [timing[0] / 1000.0, timing[1]])
	for line in failed:
		printerr("FAIL ", line)
	var notes := "%d long ones skipped (run with -- --full)" % skipped
	if filtered > 0:
		notes += ", %d filtered out" % filtered
	print("tests: %d passed, %d failed, %s" % [passed, failed.size(), notes])
	quit(1 if failed.size() > 0 or passed == 0 else 0)


## `--name=a,b` の形の引数を、文字列の並びにして返す（無ければ空）。
func _list_arg(args: PackedStringArray, prefix: String) -> PackedStringArray:
	for arg in args:
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix).split(",", false)
	return PackedStringArray()


func _matches(label: String, patterns: PackedStringArray) -> bool:
	for pattern in patterns:
		if label.contains(pattern):
			return true
	return false


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
