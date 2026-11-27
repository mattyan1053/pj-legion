extends RefCounted
## 軍で決まる見た目の表（ルールの値は rules/armies.gd。名前は文の表の army.<鍵>）。
## 軍の色・紋・空の色・物語の景色の構えを、ここ 1 か所から読む（docs/unit-roster.md の「軍を足すとき」）。
##
## 表の欄:
## - color: 国の色（物語のカードの帯と紋、軍略の札・印・線、部隊編成の軍の名前）
## - crest: 紋の形（game/crest.gd が描く。gear = 歯車と山形、crystal = 結晶の菱形と星）
## - sky: 物語の景色で、空をこの色へ寄せる（game/title_backdrop.gd）
## - view: 物語の景色の構え（game/title_backdrop.gd の VIEWS の鍵。その国の側の空へ向く）

const Palette := preload("res://game/ui_palette.gd")

const _BUILT_IN := {
	UnitKind.Army.MILITARY: {
		"color": Palette.NATION_MILITARY,
		"crest": &"gear",
		"sky": Color(0.80, 0.50, 0.28),
		"view": &"berg_map",
	},
	UnitKind.Army.FANTASY: {
		"color": Palette.NATION_FANTASY,
		"crest": &"crystal",
		"sky": Color(0.50, 0.36, 0.86),
		"view": &"ruel_map",
	},
}

## いまの表（テストが仮の軍を足すときだけ替わる。add_for_test）。
static var _table: Dictionary = _BUILT_IN


## 表にある軍か。
static func has(army: int) -> bool:
	return _table.has(army)


## 国の色。表に無い軍（軍なしも）は、表の最初の軍の色。
static func color(army: int) -> Color:
	return _row(army).get("color", (_table.values()[0] as Dictionary)["color"])


## 紋の形。表に無い軍は、表の最初の軍の紋。
static func crest(army: int) -> StringName:
	return _row(army).get("crest", (_table.values()[0] as Dictionary)["crest"])


## 空を寄せる色。表に無い軍なら透明（寄せない）。
static func sky(army: int) -> Color:
	return _row(army).get("sky", Color(0, 0, 0, 0))


## 物語の景色の構え。表に無い軍は、表の最初の軍の構え。
static func view(army: int) -> StringName:
	return _row(army).get("view", (_table.values()[0] as Dictionary)["view"])


static func _row(army: int) -> Dictionary:
	return _table.get(army, {})


# ---- テストだけが使う ----


## 仮の軍 army の見た目を、表の終わりに足す（tests/rules/test_armies.gd と組で使う）。reset_for_test で戻す。
static func add_for_test(army: int, row: Dictionary) -> void:
	var table := _table.duplicate()
	table[army] = row
	_table = table


static func reset_for_test() -> void:
	_table = _BUILT_IN
