extends RefCounted
## クレジット（docs/credits.md）: 入れた素材の、名前・作者・出どころ・ライセンスの表（game/credits.csv）を読む。ノードに依存しない。
## タイトルの「クレジット」の窓（credits_panel.gd）と、書き出しに添える文書（addons/credits_export/ の CREDITS.txt）が、同じこの表から作る。
## 表は 1 行 1 素材で「group,name,author,source,license,license_file」。group は GROUPS のどれか。license_file はリポジトリの中のライセンスの文。

const Text := preload("res://game/text.gd")

## 表の置き場所。
const TABLE := "res://game/credits.csv"
## 種類の並び（画面と文書の見出しの順）。見出しの文は表の credits.group.<種類>。
const GROUPS: Array[String] = ["font", "unit", "board", "sound"]
## 表の列。
const COLUMNS: Array[String] = ["group", "name", "author", "source", "license", "license_file"]


## 表の行（{列の名前: 値} の並び。表に書いた順）。読めなければ空。
static func rows() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var file := FileAccess.open(TABLE, FileAccess.READ)
	if file == null:
		push_error("credits: %s を開けない" % TABLE)
		return found
	var head := file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < head.size() or line[0] == "":
			continue
		var row := {}
		for i in head.size():
			row[head[i]] = line[i]
		found.append(row)
	return found


## 種類 group の行。
static func rows_of(group: String) -> Array[Dictionary]:
	return rows().filter(func(row: Dictionary) -> bool: return row["group"] == group)


## 表に出てくるライセンスの文のファイル（重ねない。表の順）。
static func license_files() -> Array[String]:
	var files: Array[String] = []
	for row in rows():
		if not files.has(row["license_file"]):
			files.append(row["license_file"])
	return files


## 書き出しに添える文書（CREDITS.txt）の中身。種類ごとに、素材名・作者・出どころ・ライセンス。最後に、ライセンスの文の置き場所。
static func text() -> String:
	var lines: Array[String] = [Text.t("credits.title"), ""]
	for group in GROUPS:
		lines.append(Text.t("credits.group_head", {"group": Text.t("credits.group." + group)}))
		for row in rows_of(group):
			lines.append(Text.t("credits.line", {"name": row["name"], "author": row["author"], "license": row["license"]}))
			lines.append("    " + row["source"])
		lines.append("")
	lines.append(Text.t("credits.license_files"))
	for path in license_files():
		lines.append("    licenses/" + license_copy_name(path))
	return "\n".join(lines) + "\n"


## ライセンスの文を、書き出しの licenses/ に置くときの名前（パスの / を - にする。「assets-fonts-zen-LICENSE-ZenOldMincho.txt」）。
static func license_copy_name(path: String) -> String:
	return path.trim_prefix("res://").replace("/", "-")
