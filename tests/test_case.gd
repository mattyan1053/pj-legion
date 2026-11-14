extends RefCounted
## テストの土台。`tests/` の下の `test_*.gd` がこれを継承し、`test_` で始まるメソッドを並べる。
## メソッド 1 つごとに新しいインスタンスで呼ばれるので、メンバ変数は持ち越されない。

var failures: PackedStringArray = []


## 条件が成り立つことを確かめる。
func check(condition: bool, message: String = "") -> void:
	if not condition:
		_fail("条件が成り立たない", message)


## 2 つの値が等しいことを確かめる。配列と辞書は中身で比べる。
func eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		_fail("期待 %s / 実際 %s" % [var_to_str(expected), var_to_str(actual)], message)


func _fail(what: String, message: String) -> void:
	failures.append(what if message.is_empty() else "%s: %s" % [message, what])
