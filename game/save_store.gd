extends RefCounted
## 取っておくもの（設定など）を、まとまりごとに 1 つの JSON のファイルにして置く。ノードに依存しない。
##
## ファイルは <dir>/<名前>.json で、中身は {"name": 名前, "version": 形式の版, "data": 中身}。
## 版を見て読み替えるのは、使う側（settings.gd など）の仕事。ここは、壊れたファイル・読めないファイルを
## 「無い」として返すだけで、起動を止めない。
## 置いているもの: 設定（"settings"。settings.gd）、対戦用の部隊（"decks"。deck_library.gd）、
## セーブのスロット（"slot_1" など。save_slots.gd。ストーリーの進み具合とストーリー用の部隊）。

## 名前に使える文字（ファイル名にそのまま使うので、英小文字・数字・_ と - だけ）。
const NAME_PATTERN := "^[a-z0-9_-]+$"

var dir: String


## base_dir の下に置く（既定は user://。検査では、別のディレクトリを渡す）。
func _init(base_dir := "user://") -> void:
	dir = base_dir


func path_of(name: String) -> String:
	return dir.path_join(name + ".json")


## name のまとまりを読む。{"version": 版, "data": 中身} を返す。
## 無い、読めない、JSON でない、形が違う（data が辞書でない、版が数でない）ときは、空の辞書を返す。
func read(name: String) -> Dictionary:
	var found := inspect(name)
	if found["state"] != OK_STATE:
		return {}
	return {"version": found["version"], "data": found["data"]}


## 読めたか。MISSING（無い）、BROKEN（あるが読めない）、OK_STATE（読めた）。
const MISSING := &"missing"
const BROKEN := &"broken"
const OK_STATE := &"ok"


## name のまとまりを読み、無いのか、あるが壊れているのかも分けて返す（セーブのスロットが、壊れたファイルを空きと見ないため）。
## {"state": MISSING / BROKEN / OK_STATE, "version": 版, "data": 中身}（版と中身は OK_STATE のときだけ）。
func inspect(name: String) -> Dictionary:
	if not _valid_name(name):
		return {"state": MISSING}
	var path := path_of(name)
	if not FileAccess.file_exists(path):
		return {"state": MISSING}
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return {"state": BROKEN}
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("save_store: %s は JSON として読めないので、無いものとする（%s）" % [path, json.get_error_message()])
		return {"state": BROKEN}
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"state": BROKEN}
	var version: Variant = parsed.get("version")
	var data: Variant = parsed.get("data")
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or typeof(data) != TYPE_DICTIONARY:
		return {"state": BROKEN}
	return {"state": OK_STATE, "version": int(version), "data": data}


## name のまとまりのファイルがあるか（読めるかは見ない）。
func exists(name: String) -> bool:
	return _valid_name(name) and FileAccess.file_exists(path_of(name))


## name のまとまりのファイルを、名前 to のファイルへ写す（中身は見ない。前のセーブを残しておくため）。写せたか。
func copy_file(name: String, to: String) -> bool:
	if not exists(name) or not _valid_name(to):
		return false
	return DirAccess.copy_absolute(path_of(name), path_of(to)) == OK


## name のまとまりのファイルを、名前 to へ移す（to にあれば置き換える）。移せたか。
func rename_file(name: String, to: String) -> bool:
	if not exists(name) or not _valid_name(to):
		return false
	if exists(to):
		DirAccess.remove_absolute(path_of(to))
	return DirAccess.rename_absolute(path_of(name), path_of(to)) == OK


## name のまとまりのファイルを最後に書いた時刻（Unix 時刻、秒。無ければ 0）。
func modified_time(name: String) -> int:
	return FileAccess.get_modified_time(path_of(name)) if exists(name) else 0


## name のまとまりを、版 version の中身 data として書く。書けたかを返す。
## 書きかけで止まっても前のファイルが壊れないよう、一時のファイルに書いてから置き換える。
func write(name: String, version: int, data: Dictionary) -> bool:
	if not _valid_name(name):
		push_error("save_store: 名前に使えない文字がある: %s" % name)
		return false
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var path := path_of(name)
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_warning("save_store: %s を書けない（%s）" % [temporary, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify({"name": name, "version": version, "data": data}, "\t") + "\n")
	file.close()
	if DirAccess.rename_absolute(temporary, path) != OK:
		push_warning("save_store: %s を置き換えられない" % path)
		DirAccess.remove_absolute(temporary)
		return false
	return true


## name のまとまりを消す（無ければ何もしない）。
func remove(name: String) -> void:
	if _valid_name(name) and FileAccess.file_exists(path_of(name)):
		DirAccess.remove_absolute(path_of(name))


static func _valid_name(name: String) -> bool:
	return RegEx.create_from_string(NAME_PATTERN).search(name) != null
