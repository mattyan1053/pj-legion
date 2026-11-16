extends RefCounted
## 手で作ったマップ（docs/hand-map.md）を、名前（id）で引く。話のファイル（episode.gd）が map = <id> で指す。ノードに依存しない。

## マップを置く所（ファイルの名前が id）。
const DIR := "res://rules/maps/"


## id のマップ: {"map": HandMap, "title": 名前}。無ければ空。
static func find(id: String) -> Dictionary:
	var file_path := DIR + id + ".gd"
	if id == "" or not id.is_valid_filename() or not ResourceLoader.exists(file_path):
		return {}
	var script: Script = load(file_path)
	return {"map": script.map(), "title": script.TITLE}
