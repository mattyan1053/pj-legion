class_name StateCopy
extends RefCounted
## 状態を持つオブジェクトの複製を手伝う（Battle.clone() が使う）。
##
## スクリプトで宣言した変数を、名前で拾って写す。変数を足しても、写し忘れが起きない。
## 配列・辞書・Packed*Array は中身ごと複製する（GDScript では、どれも代入だけでは元と共有する）。
## オブジェクト（駒、盤面、乱数など）を持つ変数は、そのままでは元と共有してしまうので写さない。
## 呼ぶ側が handled に名前を挙げて自分で複製する。挙げ忘れたら assert で止まる。


static func copy_fields(from: Object, to: Object, handled: Array[StringName] = []) -> void:
	for property in from.get_property_list():
		if not (property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var name: StringName = property["name"]
		if handled.has(name):
			continue
		var value: Variant = from.get(name)
		assert(not _holds_object(value), "%s.%s はオブジェクトを持つので、自分で複製する" % [from.get_script().get_global_name(), name])
		if value is Array or value is Dictionary:
			value = value.duplicate(true)
		elif typeof(value) >= TYPE_PACKED_BYTE_ARRAY and typeof(value) < TYPE_MAX:
			value = value.duplicate()
		to.set(name, value)


static func _holds_object(value: Variant) -> bool:
	if value is Object:
		return true
	if value is Array:
		if value.get_typed_builtin() == TYPE_OBJECT:
			return true  # いまは空でも、駒などが入る配列
		for item: Variant in value:
			if _holds_object(item):
				return true
	if value is Dictionary:
		for key: Variant in value:
			if _holds_object(key) or _holds_object(value[key]):
				return true
	return false
