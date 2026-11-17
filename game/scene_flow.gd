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
## - 流れが渡すものは context.run_data() で受け取る（アプリが、いまの場面の名前を context に入れてある）。
##   - resume_label() -> String: システムメニューの「戻る」の文字（既定は「戻る」）。
##   - menu_items() -> Array: システムメニューに足す項目（[名前, 文字, 確かめの文] の列）。選ばれたら on_menu_item(名前)。
##   - in_progress() -> bool: 抜けると失われるものがあるか（あれば、タイトルへ戻る・ゲームを終える前に確かめる）。
##   - losing_note() -> String: 確かめの文に書く、失われるもの（既定は「対戦の状態は失われます。」）。

## 場面の名前。ほかのスクリプトは、場面を名前で指すとき、文字で書かずにこれを使う（書き漏らすと、流れが渡すものを受け取れず、
## エラーにならずに既定の中身で始まる）。
const TITLE := &"title"
const CAMPAIGNS := &"campaigns"
const EPISODES := &"episodes"
const DECKS := &"decks"
const MAP_SELECT := &"map_select"
const SETUP := &"setup"
const TALK := &"talk"
const SORTIE := &"sortie"
const BATTLE := &"battle"

## 場面の名前 -> {script: スクリプト, next: {終わり方 -> 次の場面}, music: その場面で鳴らす曲（sound_catalog.gd の名前。無ければ鳴らさない）}。
## 同じ曲の場面どうしを行き来しても、曲は途切れない（sound.gd）。
const SCENES := {
	TITLE: {
		"script": "res://game/title_screen.gd",
		"next": {&"start": MAP_SELECT, &"story": CAMPAIGNS},
		"music": &"menu",
	},
	CAMPAIGNS: {
		"script": "res://game/campaign_list_screen.gd",
		"next": {&"open": EPISODES, &"back": TITLE},  # 物語を選ぶと、その物語の話の一覧へ
		"music": &"menu",
	},
	EPISODES: {
		"script": "res://game/episode_list_screen.gd",
		"next": {&"back": CAMPAIGNS},  # 話を選ぶと、話の流れ（story.gd の run_now）を始める。流れを終えたら、ここへ戻る
		"music": &"menu",
	},
	DECKS: {
		"script": "res://game/deck_screen.gd",
		"next": {&"back": TITLE},  # 対戦設定・出撃準備からの寄り道（流れの中）で開く。戻るのは Run.NEXT
		"music": &"menu",
	},
	MAP_SELECT: {
		"script": "res://game/map_select_screen.gd",
		"next": {&"pick": SETUP, &"back": TITLE},
		"music": &"menu",
	},
	SETUP: {
		"script": "res://game/setup_screen.gd",
		"next": {&"back": MAP_SELECT},  # 「対戦を始める」は、対戦の流れ（run.gd）を始める（setup_screen.gd）
		"music": &"menu",
	},
	TALK: {
		"script": "res://game/talk_screen.gd",
		"next": {},  # 流れの中でだけ使う（ストーリーの会話。Run.NEXT で次へ）
		"music": &"talk",  # 話のファイルの talk_music で選び直せる（episode.gd）
	},
	SORTIE: {
		"script": "res://game/sortie_screen.gd",
		"next": {&"back": EPISODES},  # 流れの中でだけ使う（ストーリーの出撃準備。「出撃」は Run.NEXT で対戦へ。「部隊編成」は流れに編成を差し込む）
		"music": &"menu",
	},
	BATTLE: {
		"script": "res://game/battle_screen.gd",
		"next": {&"setup": SETUP, &"map_select": MAP_SELECT, &"episodes": EPISODES},  # 「マップを選び直す」（対戦の途中で開いた対戦設定）は、マップ選択へ
		"music": &"battle",  # 既定。ふつうは渡すもの（battle_source.gd の music: 盤の見た目か、話が決めた曲）が決める
	},
}
## 起動して最初に出す場面。
const FIRST := TITLE
## どの場面からでも行ける行き先（終わり方 -> 場面）。システムメニューの「タイトルへ戻る」と、決着の画面の「タイトルへ」。
const COMMON := {&"title": TITLE}


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


## 場面 scene を、流れが渡すもの given で始めるときの曲。given が曲を決めていれば（music() を持つもの、"music" の欄を持つ辞書）、
## その曲。決めていない（空の名前）なら、場面の表の曲（music）。
static func music_for(scene: StringName, given: Variant) -> StringName:
	var track := &""
	if given is Object and (given as Object).has_method(&"music"):
		track = given.music()
	elif given is Dictionary:
		track = (given as Dictionary).get("music", &"")
	return track if track != &"" else music(scene)
