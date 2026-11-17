extends "res://tests/base_test.gd"
## 駒の見た目の組（game/unit_looks.gd と game/looks/）。

const UnitLooks := preload("res://game/unit_looks.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const UnitView := preload("res://game/unit_view.gd")


## どの組も、どの種類の駒（将の別の姿も）にも体を作り、高さを返す。
func test_every_set_builds_every_kind() -> void:
	for name: StringName in UnitLooks.SETS:
		var looks := UnitLooks.of(name)
		for kind: UnitKind.Id in UnitKind.Id.values():
			var body := looks.build(kind, Color.RED, &"", Vector3.ZERO)
			assert_true(body != null and body.body_height > 0.3, "%s: %s の体" % [name, UnitKind.Id.keys()[kind]])
			body.free()
		for look: StringName in UnitLooks.KING_LOOKS:
			var body := looks.build(UnitKind.Id.KING, Color.RED, look, Vector3.ZERO)
			assert_true(body != null and body.body_height > 0.3, "%s: 将の姿 %s" % [name, look])
			body.free()


## どの組にも、写したアイコンが全部ある（無ければ tools/unit_icons.sh <godot> <組> で写す）。
func test_every_set_has_every_icon() -> void:
	for name: StringName in UnitLooks.SETS:
		var dir := UnitLooks.of(name).icon_dir
		for variant: Array in UnitIcons.variants():
			var file := UnitIcons.file_name(variant[0], variant[1], variant[2], variant[3])
			assert_true(ResourceLoader.exists("%s/%s" % [dir, file]), "%s: アイコンが無い: %s" % [name, file])


## 組を替えると、アイコンもその組の絵になる。知らない名前は既定の組。
func test_use_switches_icons() -> void:
	UnitLooks.use(&"no_such_set")
	assert_eq(UnitLooks.active_name(), UnitLooks.DEFAULT)
	for name: StringName in UnitLooks.SETS:
		UnitLooks.use(name)
		var texture := UnitIcons.texture(UnitKind.Id.SNIPER, 0)
		assert_true(texture != null and texture.resource_path.begins_with(UnitLooks.of(name).icon_dir + "/"), "%s のアイコン" % name)
	UnitLooks.use(UnitLooks.DEFAULT)


## 駒の見た目は、組の体を子に持ち、将には冠のぶん高さを足す。
func test_view_uses_the_body_height() -> void:
	for name: StringName in UnitLooks.SETS:
		var view := UnitView.new()
		view.setup(UnitKind.Id.KING, Color.BLUE, 30, 30, &"", name)
		var body := UnitLooks.of(name).build(UnitKind.Id.KING, Color.BLUE, &"", Vector3.ZERO)
		assert_true(is_equal_approx(view.height(), body.body_height + 0.2), "%s: 将の高さ" % name)
		body.free()
		view.free()
