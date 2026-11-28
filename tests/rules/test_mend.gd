extends "res://tests/base_test.gd"
## 回復の共通の道（Mend）: 上限で止める、出来事に結果を書く。rules/ の中で HP を書き換えるのは Mend と Hit だけ。

const Maps := preload("res://tests/support/maps.gd")

const ROOT := "res://rules"


func test_give_stops_at_max_hp_and_fills_the_event() -> void:
	var battle := Maps.battle(["...."])
	var unit := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(0, 0))
	unit.hp = unit.max_hp() - 3
	var event := Mend.give(unit, 10, SupplyHealedEvent.new(7)) as SupplyHealedEvent
	assert_eq(unit.hp, unit.max_hp())
	assert_eq(event.medic_id, 7)
	assert_eq(event.unit_id, unit.id)
	assert_eq(event.amount, 3)
	assert_eq(event.hp, unit.max_hp())
	assert_eq(Mend.amount(unit, 10), 0)  # 満タンなら 0（負にならない）


## rules/ の中で HP を書き換えてよい所の全部（ファイル -> 関数 -> 書き方）。ここに無い所で HP を書くと落ちる。
## 増やすのは Mend.give、減らすのは Hit.apply（docs/battle.md の「回復を 1 つ足すとき」）。
## ほかは、駒を作るときに満タンにする所と、最大 HP が変わったときに合わせる所だけ。
## 出来事（rules/events/）が自分の hp（あとの HP の控え）を書くのは、駒の HP ではないので数えない。
const HP_WRITERS := {
	"res://rules/mend.gd": {"give": ["+=", "="]},  # "=" は、出来事にあとの HP を書く所
	"res://rules/hit.gd": {"apply": ["-="]},
	"res://rules/unit.gd": {"_init": ["="], "follow_max_hp": ["+=", "="]},
}

## 「hp」へ書く形（hp = / hp += / hp -= / hp *= など。前に「何か.」が付いてもよい）。比べる形（==・<=・>=・!=）は拾わない。
const WRITE := "(\\.)?\\bhp\\s*([-+*/%]?=)(?!=)"
## 名前の文字で HP に触る形（set("hp", …) など）。
const BY_NAME := "[&^]?[\"']hp[\"']"


func test_only_mend_and_hit_change_hp_in_the_rules() -> void:
	var seen := {}
	for path: String in _scripts(ROOT):
		for found: Array in _hp_writes(path):
			var where: String = found[0]
			var op: String = found[1]
			var line: String = found[2]
			if found[3] and path.begins_with(ROOT.path_join("events")):
				continue  # 出来事が自分の hp を書く
			var allowed: Array = HP_WRITERS.get(path, {}).get(where, [])
			assert_true(allowed.has(op),
				"%s の %s が HP を直に書いている（増やすなら Mend.give、減らすなら Hit を通す）: %s" % [path, where, line.strip_edges()])
			seen["%s %s %s" % [path, where, op]] = true
		var source := _code_of(path)
		assert_true(RegEx.create_from_string(BY_NAME).search(source) == null,
			"%s が名前の文字で hp に触っている（Mend.give か Hit を通す）" % path)
	# 表が古くならない（書いてある所が、実際に書いている）
	for path: String in HP_WRITERS:
		for where: String in HP_WRITERS[path]:
			for op: String in HP_WRITERS[path][where]:
				assert_true(seen.has("%s %s %s" % [path, where, op]), "HP_WRITERS の %s %s %s は、もう書いていない（表から消す）" % [path, where, op])


## path の中で hp へ書く行: [関数の名前, 書き方, 行, 前に「何か.」が無いか]。
func _hp_writes(path: String) -> Array:
	var write := RegEx.create_from_string(WRITE)
	var func_name := RegEx.create_from_string("^\\s*(?:static\\s+)?func\\s+(\\w+)")
	var outside := RegEx.create_from_string("^(?:static\\s+var|var|const|enum|signal|class|@)\\b")
	var result := []
	var where := ""
	for line in _code_of(path).split("\n"):
		var head := func_name.search(line)
		if head != null:
			where = head.get_string(1)
		elif outside.search(line) != null:
			where = ""  # 関数の外（クラスの変数など）
		for found in write.search_all(line):
			result.append([where, found.get_string(2), line, found.get_string(1).is_empty()])
	return result


## コメントを除いたソース（# から行の終わりまでを消す）。
func _code_of(path: String) -> String:
	var lines: PackedStringArray = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var mark := line.find("#")
		lines.append(line if mark < 0 else line.substr(0, mark))
	return "\n".join(lines)


func _scripts(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	for sub in DirAccess.get_directories_at(dir_path):
		found.append_array(_scripts(dir_path.path_join(sub)))
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	return found
