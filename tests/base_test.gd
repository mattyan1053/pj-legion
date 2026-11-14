extends RefCounted
## テストの土台。テストのファイルはこれを extends し、`test_` で始まるメソッドを書く。
##
##   extends "res://tests/base_test.gd"
##
##   func test_something() -> void:
##       assert_eq(1 + 1, 2)
##
## メソッドごとに新しいインスタンスで実行する（テストどうしで状態を持ち越さない）。
## 失敗しても止めずに最後まで実行し、失敗した箇所をすべて報告する。

var failures: Array[String] = []


func assert_true(condition: bool, message := "") -> void:
	if not condition:
		_fail("真であるはずが偽", message)


func assert_false(condition: bool, message := "") -> void:
	if condition:
		_fail("偽であるはずが真", message)


func assert_eq(actual: Variant, expected: Variant, message := "") -> void:
	if not _same(actual, expected):
		_fail("%s であるはずが %s" % [var_to_str(expected), var_to_str(actual)], message)


func assert_ne(actual: Variant, unexpected: Variant, message := "") -> void:
	if _same(actual, unexpected):
		_fail("%s でないはずが一致" % var_to_str(unexpected), message)


func assert_between(actual: float, low: float, high: float, message := "") -> void:
	if actual < low or actual > high:
		_fail("%s〜%s のはずが %s" % [low, high, actual], message)


func _same(a: Variant, b: Variant) -> bool:
	# 1 と 1.0 のように型だけ違う数は同じとみなす。それ以外は型も中身も一致を求める。
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b


func _fail(what: String, message: String) -> void:
	var where := ""
	for frame: Dictionary in get_stack():
		if not String(frame["source"]).ends_with("base_test.gd"):
			where = "%s:%d" % [String(frame["source"]).get_file(), frame["line"]]
			break
	failures.append("%s %s%s" % [where, what, "（%s）" % message if message else ""])
