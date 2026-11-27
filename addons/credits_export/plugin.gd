@tool
extends EditorPlugin
## 書き出しのときに、クレジットの文書を exe の隣に置く（export_plugin.gd）。docs/credits.md。

const CreditsExport := preload("res://addons/credits_export/export_plugin.gd")

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = CreditsExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null
