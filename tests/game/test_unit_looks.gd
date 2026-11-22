extends "res://tests/base_test.gd"
## 駒の見た目の組（game/unit_looks.gd と game/looks/）。

const UnitLooks := preload("res://game/unit_looks.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const UnitView := preload("res://game/unit_view.gd")
const Settings := preload("res://game/settings.gd")


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


## 名前のある人物の形: 「人形」の組は、人物ごとに部品を付け替えた形を作る。ほかの組（人物の形を持たない）は、駒の種類の形のまま。
func test_people_have_their_own_shapes() -> void:
	for person: StringName in UnitLooks.PERSONS:
		var kind: UnitKind.Id = UnitLooks.PERSONS[person]
		for name: StringName in UnitLooks.SETS:
			var view := UnitView.new()
			Engine.get_main_loop().root.add_child(view)
			view.setup(kind, Color.RED, 10, 20, person, name)
			assert_true(view.height() > 0.3, "%s: %s の体" % [name, person])
			view.play_run()
			assert_true(view.play_attack() > 0.0, "%s: %s の攻撃" % [name, person])
			view.free()
	var kaykit := UnitLooks.of(&"kaykit")
	assert_true(not UnitLooks.of(&"mini").has_person(&"ul"))
	# ウル: 衣の魔法使いの頭を、禿げ頭にひげの頭に替え、帽子を脱ぐ。杖と本を持つ。
	var ul := kaykit.build(UnitKind.Id.PRIEST, Color.RED, &"ul", Vector3.ZERO)
	assert_eq(_shown_meshes(ul).filter(func(each: String) -> bool: return each.ends_with("_Head")), ["Barbarian_Head"])
	assert_true(not _shown_meshes(ul).has("Mage_Hat") and _shown_meshes(ul).has("2H_Staff") and _shown_meshes(ul).has("Spellbook"), "%s" % [_shown_meshes(ul)])
	ul.free()
	# セリス: 軽装（Rogue）に、騎士の両手剣を借りて持つ。
	var seris := kaykit.build(UnitKind.Id.SPELLBLADE, Color.RED, &"seris", Vector3.ZERO)
	assert_true(_shown_meshes(seris).has("2H_Sword") and _shown_meshes(seris).has("Rogue_Head") and not _shown_meshes(seris).has("2H_Crossbow"), "%s" % [_shown_meshes(seris)])
	seris.free()
	# 人物の形は、将の駒に付いても（将の印の人）その人の形。
	var yelda := kaykit.build(UnitKind.Id.KING, Color.RED, &"yelda", Vector3.ZERO)
	assert_true(_shown_meshes(yelda).has("Rogue_Head") and _shown_meshes(yelda).has("Badge_Shield"), "%s" % [_shown_meshes(yelda)])
	yelda.free()
	# 「人形 2」の組: 頭を別の人物の頭に替え、頭に合わせた帽子・兜は外す。
	var kaykit2 := UnitLooks.of(&"kaykit2")
	var ul2 := kaykit2.build(UnitKind.Id.PRIEST, Color.RED, &"ul", Vector3.ZERO)
	var ul2_shown := _shown_meshes(ul2)
	assert_eq(ul2_shown.filter(func(each: String) -> bool: return each.ends_with("_Head")), ["Barbarian_Head"])
	assert_true(not ul2_shown.has("Mage_Hat") and ul2_shown.has("Mage_Body") and ul2_shown.has("Mage_Cape"), "%s" % [ul2_shown])
	ul2.free()
	var dawson2 := kaykit2.build(UnitKind.Id.SHIELD_TROOPER, Color.RED, &"dawson", Vector3.ZERO)
	var dawson2_shown := _shown_meshes(dawson2)
	assert_true(dawson2_shown.has("Engineer_Head") and not dawson2_shown.has("Knight_Helmet") and dawson2_shown.has("Knight_Body"), "%s" % [dawson2_shown])
	dawson2.free()
	# 将の別の姿（骸骨の将）は、「人形」の組の骸骨の将（騎士にならない）。
	var skeleton_king := kaykit2.build(UnitKind.Id.KING, Color.RED, &"skeleton_mage", Vector3.ZERO)
	assert_true(not _shown_meshes(skeleton_king).has("Knight_Body"), "%s" % [_shown_meshes(skeleton_king)])
	skeleton_king.free()


## 見えている面の名前（親が隠れていれば見えない）。
func _shown_meshes(body: Node) -> Array:
	var names: Array = []
	for mesh: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		var shown := true
		var node: Node = mesh
		while node != body:
			if node is Node3D and not (node as Node3D).visible:
				shown = false
			node = node.get_parent()
		if shown:
			names.append(String(mesh.name))
	return names


## どの組にも、写したアイコンが全部ある（無ければ tools/unit_icons.sh <godot> <組> で写す）。
func test_every_set_has_every_icon() -> void:
	for name: StringName in UnitLooks.SETS:
		var dir := UnitLooks.of(name).icon_dir
		for variant: Array in UnitIcons.variants(name):
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


## オプションの「駒の見た目」の選択肢は、組の並び（ORDER）と同じ数で、どの組も選べる。既定は既定の組。
func test_settings_choices_match_the_sets() -> void:
	var entry := Settings.item(Settings.UNIT_LOOK)
	assert_eq(entry["choices"].size(), UnitLooks.ORDER.size())
	for index in UnitLooks.ORDER.size():
		assert_eq(entry["choices"][index][0], index)
		assert_true(UnitLooks.SETS.has(UnitLooks.ORDER[index]), "ORDER の %s" % UnitLooks.ORDER[index])
	assert_eq(UnitLooks.SETS.size(), UnitLooks.ORDER.size())
	assert_eq(UnitLooks.name_at(entry["default"]), UnitLooks.DEFAULT)
	assert_eq(UnitLooks.name_at(-1), UnitLooks.DEFAULT)
	assert_eq(UnitLooks.name_at(UnitLooks.ORDER.size()), UnitLooks.DEFAULT)


## どの組の体も、攻撃・被弾・倒れる・走る・身ぶりの動きを、エラー無く始められる（動きの無い組は代わりの動き）。
func test_every_body_can_move() -> void:
	for name: StringName in UnitLooks.SETS:
		for kind: UnitKind.Id in [UnitKind.Id.KING, UnitKind.Id.SNIPER, UnitKind.Id.MINION, UnitKind.Id.SKELETON_BRUTE]:
			var view := UnitView.new()
			Engine.get_main_loop().root.add_child(view)
			view.setup(kind, Color.RED, 10, 20, &"", name)
			view.play_run()
			view.play_idle()
			view.play_gesture()
			assert_true(view.play_attack() > 0.0, "%s: %s の攻撃の当たる時" % [name, UnitKind.Id.keys()[kind]])
			view.play_hit()
			view.set_acted(true)
			view.set_acted(false)
			view.free()
