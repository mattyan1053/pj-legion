extends RefCounted
## 場面の種類と、その並び（どの場面が、どう終わったら、次にどの場面へ進むか）。ノードに依存しない。
##
## **場面を 1 つ足すのは、SCENES に 1 つ足すだけ**（と、その場面のスクリプト）。アプリ（app.gd）は、この表のとおりに進める。
## 同じ場面を、違うものを渡して順に使う並び（ストーリーの 1 話の、会話 → 対戦 → 会話）は、ここではなく流れ（run.gd）で並べる。
## 流れの中の場面にも、ここに 1 行（スクリプトと、流れの外へ出る終わり方）は要る。
##
## 場面のスクリプトの決まり（app.gd が使う）:
## - extends Node（3D の場面も 2D の場面もよい）。
## - var context（app_context.gd）を持つ。アプリが、作ってから木に入れる前に入れる。
## - signal finished(outcome: StringName) を持つ。outcome は、SCENES の next か COMMON の名前か、流れの中なら Run.NEXT。
## - 次のものは、あれば使う（無くてよい）:
##   - resume_label() -> String: システムメニューの「戻る」の文字（既定は「戻る」）。
##   - menu_items() -> Array: システムメニューに足す項目（[名前, 文字, 確かめの文] の列）。選ばれたら on_menu_item(名前)。
##   - in_progress() -> bool: 抜けると失われるものがあるか（あれば、タイトルへ戻る・ゲームを終える前に確かめる）。

## 場面の名前 -> {script: スクリプト, next: {終わり方 -> 次の場面}, music: その場面で鳴らす曲（sound_catalog.gd の名前。無ければ鳴らさない）}。
## 同じ曲の場面どうしを行き来しても、曲は途切れない（sound.gd）。
const SCENES := {
	&"title": {
		"script": "res://game/title_screen.gd",
		"next": {&"start": &"stage", &"decks": &"decks"},
		"music": &"menu",
	},
	&"decks": {
		"script": "res://game/deck_screen.gd",
		"next": {&"back": &"title"},
		"music": &"menu",
	},
	&"stage": {
		"script": "res://game/stage_select_screen.gd",
		"next": {&"pick": &"setup", &"back": &"title"},
		"music": &"menu",
	},
	&"setup": {
		"script": "res://game/setup_screen.gd",
		"next": {&"back": &"stage"},  # 「対戦を始める」は、対戦の流れ（run.gd）を始める（setup_screen.gd）
		"music": &"menu",
	},
	&"battle": {
		"script": "res://game/battle_screen.gd",
		"next": {&"setup": &"setup"},
		"music": &"battle",
	},
}
## 起動して最初に出す場面。
const FIRST := &"title"
## どの場面からでも行ける行き先（終わり方 -> 場面）。システムメニューの「タイトルへ戻る」と、決着の画面の「タイトルへ」。
const COMMON := {&"title": &"title"}


static func has(scene: StringName) -> bool:
	return SCENES.has(scene)


## scene が outcome で終わったときの次の場面。決まっていなければ空の名前（進まない）。
static func next(scene: StringName, outcome: StringName) -> StringName:
	if not SCENES.has(scene):
		return &""
	var table: Dictionary = SCENES[scene]["next"]
	if table.has(outcome):
		return table[outcome]
	return COMMON.get(outcome, &"")


static func script_path(scene: StringName) -> String:
	return SCENES[scene]["script"] if SCENES.has(scene) else ""


## scene で鳴らす曲の名前（sound_catalog.gd の MUSIC）。決まっていなければ空（曲を止める）。
static func music(scene: StringName) -> StringName:
	return SCENES[scene].get("music", &"") if SCENES.has(scene) else &""
