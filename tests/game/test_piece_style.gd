extends "res://tests/base_test.gd"
## 駒の縁取り（game/piece_style.gd。オプションの「駒の縁取り」）。

const PieceStyle := preload("res://game/piece_style.gd")
const UnitView := preload("res://game/unit_view.gd")
const UnitLooks := preload("res://game/unit_looks.gd")
const Settings := preload("res://game/settings.gd")


## 切りなら縁を付けず、入りなら、どの組の駒の体の面にも、裏の面を太らせた縁を付ける。
func test_outline_follows_the_switch() -> void:
	PieceStyle.outline = false
	var plain := UnitView.new()
	plain.setup(UnitKind.Id.SNIPER, Color.RED, 10, 10)
	assert_true(_overlays(plain).is_empty(), "切りなのに縁がある")
	plain.free()
	PieceStyle.outline = true
	for name: StringName in UnitLooks.SETS:
		var view := UnitView.new()
		view.setup(UnitKind.Id.SNIPER, Color.RED, 10, 10, &"", name)
		var overlays := _overlays(view)
		assert_true(not overlays.is_empty(), "%s: 縁が無い" % name)
		for material: StandardMaterial3D in overlays:
			assert_true(material.grow and material.cull_mode == BaseMaterial3D.CULL_FRONT, "%s: 縁の作り" % name)
		view.free()
	PieceStyle.outline = false


## 縁の太さは、面の大きさの倍率で割る（どの組でも同じ見た目の太さ）。
func test_outline_width_is_scaled() -> void:
	var small := PieceStyle.outline_material(0.5) as StandardMaterial3D
	var large := PieceStyle.outline_material(2.0) as StandardMaterial3D
	assert_true(is_equal_approx(small.grow_amount, PieceStyle.OUTLINE_WIDTH / 0.5))
	assert_true(is_equal_approx(large.grow_amount, PieceStyle.OUTLINE_WIDTH / 2.0))


## オプションの既定は切り。
func test_setting_default_is_off() -> void:
	assert_eq(Settings.item(Settings.PIECE_OUTLINE)["default"], false)


func _overlays(view: Node) -> Array:
	var list: Array = []
	for mesh: MeshInstance3D in view.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_overlay != null:
			list.append(mesh.material_overlay)
	return list
