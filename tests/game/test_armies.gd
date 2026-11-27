extends "res://tests/base_test.gd"
## 軍の表（rules/armies.gd と game/army_look.gd。docs/unit-roster.md の「軍を足すとき」）。
## 軍ごとに、ルールの値・見た目・文・必殺技がそろっていること。軍の二択が、表の外に戻っていないこと。

const ArmyLook := preload("res://game/army_look.gd")
const Names := preload("res://game/names.gd")
const Text := preload("res://game/text.gd")

## 軍の名前（Army.MILITARY / Army.FANTASY）を直に書いてよいファイル。
## 表そのもの、兵と必殺技（軍を名乗る側）、自動の対戦（いまの 2 軍の中身を確かめる）。
const LITERAL_OK: Array[String] = [
	"res://rules/unit_kind.gd",
	"res://rules/armies.gd",
	"res://rules/ults/",
	"res://game/army_look.gd",
	"res://game/autoplay/",
]


func test_every_army_is_in_the_table_in_order() -> void:
	var listed: Array[UnitKind.Army] = []
	for army: UnitKind.Army in UnitKind.Army.values():
		if army != UnitKind.Army.NONE:
			listed.append(army)
	assert_eq(Armies.all(), listed, "軍の表（rules/armies.gd）に、軍なし以外の軍が、列挙の順で並んでいない")
	assert_false(Armies.has(UnitKind.Army.NONE), "軍なしが軍の表にある")


func test_every_army_has_its_rules() -> void:
	for army in Armies.all():
		var name := Names.word(UnitKind.Army, army)
		assert_true(Armies.budget(army) > 0, "%s の予算が無い" % name)
		assert_eq(DeckRules.versus().budget(army), Armies.budget(army), "%s の対戦の予算が、軍の表と違う" % name)
		var traits := Armies.traits(army)
		assert_false(traits.is_empty(), "%s に軍略が無い" % name)
		var sorted_traits := traits.duplicate()
		sorted_traits.sort()
		var sorted_cpu := Armies.cpu_traits(army)
		sorted_cpu.sort()
		assert_eq(sorted_cpu, sorted_traits, "%s の CPU の軍略の順（cpu_traits）が、軍略の一覧と同じ組でない" % name)
		for each in traits:
			assert_eq(Traits.army_of(each), army, "軍略 %s が 2 つの軍にある" % Traits.key(each))
		assert_true(Ults.of_army(army) != null, "%s に必殺技が無い" % name)
		var roles := {}
		for kind in Armies.roster(army):
			roles[UnitKind.role(kind)] = true
		for role: UnitKind.Role in UnitKind.Role.values():
			if role != UnitKind.Role.NONE:
				assert_true(roles.has(role), "%s のロスターに、役割 %s の兵がいない" % [name, Names.word(UnitKind.Role, role)])
		assert_eq(DeckRules.versus().roster(army), Armies.roster(army), "%s の対戦のロスターが、軍の表と違う" % name)
	assert_eq(DeckRules.versus().armies(), Armies.all(), "対戦の決まりの軍の並びが、軍の表と違う")


func test_every_army_has_its_look_and_words() -> void:
	var colors := {}
	var crests := {}
	for army in Armies.all():
		var name := Names.word(UnitKind.Army, army)
		assert_true(ArmyLook.has(army), "軍の見た目の表（game/army_look.gd）に %s が無い" % name)
		assert_false(colors.has(ArmyLook.color(army)), "%s の色が、ほかの軍と同じ" % name)
		colors[ArmyLook.color(army)] = true
		assert_false(crests.has(ArmyLook.crest(army)), "%s の紋が、ほかの軍と同じ" % name)
		crests[ArmyLook.crest(army)] = true
		assert_true(ArmyLook.sky(army).a > 0.0, "%s の空の色が無い" % name)
		for key: String in ["army.%s", "side.story.army.%s", "side.story.army.%s.short"]:
			assert_true(Text.has(key % name), "画面の文の表に %s が無い" % (key % name))


## 軍の名前を直に書いた二択（「FANTASY なら、さもなくば」）が、表の外に戻っていないこと。
func test_no_army_is_named_outside_the_tables() -> void:
	var found: Array[String] = []
	for root: String in ["res://rules/", "res://game/"]:
		_scan(root, found)
	assert_eq(found, [] as Array[String], "軍の名前を表の外で書いている（軍の表 rules/armies.gd・game/army_look.gd から読む）")


func _scan(dir: String, found: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir + sub + "/", found)
	for file in DirAccess.get_files_at(dir):
		var path := dir + file
		if not file.ends_with(".gd") or LITERAL_OK.any(func(ok: String) -> bool: return path.begins_with(ok)):
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var code := lines[i].split("#")[0]
			if code.contains("Army.MILITARY") or code.contains("Army.FANTASY"):
				found.append("%s:%d" % [path, i + 1])
