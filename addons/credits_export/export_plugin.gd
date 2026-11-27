@tool
extends EditorExportPlugin
## 書き出した exe の隣に、クレジットの文書（CREDITS.txt。game/credits.csv から作る）と、
## 表に出てくるライセンスの文（licenses/）を書く。exe の中にも、ライセンスの文と表は入っている（export_presets.cfg の include_filter）。
## 中身は game/credits.gd が作る（クレジットの窓と同じ表から。二重に持たない）。docs/credits.md。

const Credits := preload("res://game/credits.gd")

var _target := ""


func _get_name() -> String:
	return "credits_export"


func _export_begin(_features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
	_target = path


func _export_end() -> void:
	if _target == "":
		return
	write_beside(ProjectSettings.globalize_path(_target).get_base_dir() if _target.begins_with("res://") else _target.get_base_dir())
	_target = ""


## dir に CREDITS.txt と licenses/ を書く（書き出しのほかに、検査からも呼ぶ）。書けたら真。
static func write_beside(dir: String) -> bool:
	var credits := FileAccess.open(dir.path_join("CREDITS.txt"), FileAccess.WRITE)
	if credits == null:
		push_error("credits_export: %s に CREDITS.txt を書けない" % dir)
		return false
	credits.store_string(Credits.text())
	credits.close()
	DirAccess.make_dir_recursive_absolute(dir.path_join("licenses"))
	for path in Credits.license_files():
		var from := FileAccess.open("res://" + path, FileAccess.READ)
		var to := FileAccess.open(dir.path_join("licenses").path_join(Credits.license_copy_name(path)), FileAccess.WRITE)
		if from == null or to == null:
			push_error("credits_export: %s を写せない" % path)
			return false
		to.store_string(from.get_as_text())
	return true
