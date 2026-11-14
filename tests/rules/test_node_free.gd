extends "res://tests/base_test.gd"
## rules/ の下のスクリプトがノードに依存していないこと。
## ルールは「行動を受けて、起きたことの列を返す」だけで、演出を待たない。

const ROOT := "res://rules"


func test_rule_scripts_do_not_extend_node() -> void:
	for path: String in _scripts(ROOT):
		var script: GDScript = load(path)
		var base := script.get_instance_base_type()
		assert_false(ClassDB.is_parent_class(base, &"Node"), "%s が %s を継承している" % [path, base])


func test_rule_scripts_do_not_await() -> void:
	var pattern := RegEx.create_from_string("(?m)^[^#\\n]*\\bawait\\b")
	for path: String in _scripts(ROOT):
		var source := FileAccess.get_file_as_string(path)
		assert_true(pattern.search(source) == null, "%s が await を使っている" % path)


func _scripts(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	for sub in DirAccess.get_directories_at(dir_path):
		found.append_array(_scripts(dir_path.path_join(sub)))
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	return found
