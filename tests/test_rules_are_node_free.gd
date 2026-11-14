extends "res://tests/test_case.gd"
## `rules/` の下のスクリプトがノードに依存していないことを確かめる。
## ルールは「行動を受けて、起きたことの列を返す」だけで、演出待ちを持たない。

const ROOT := "res://rules"


func test_rule_scripts_do_not_extend_node() -> void:
	for path in _scripts(ROOT):
		var script: GDScript = load(path)
		check(script != null, "%s が読み込めない" % path)
		if script != null:
			var base := script.get_instance_base_type()
			check(not ClassDB.is_parent_class(base, &"Node"), "%s が %s を継承している" % [path, base])


func test_rule_scripts_do_not_await() -> void:
	var pattern := RegEx.create_from_string("(?m)^[^#\\n]*\\bawait\\b")
	for path in _scripts(ROOT):
		var source := FileAccess.get_file_as_string(path)
		check(pattern.search(source) == null, "%s が await を使っている" % path)


func _scripts(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return found
	for dir_name in DirAccess.get_directories_at(dir_path):
		found.append_array(_scripts(dir_path.path_join(dir_name)))
	for file_name in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".gd"):
			found.append(dir_path.path_join(file_name))
	return found
