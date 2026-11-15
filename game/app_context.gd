extends RefCounted
## 場面（scene_flow.gd）どうしで共有するもの。アプリ（app.gd）が 1 つ作り、場面を作るたびに渡す。ノードに依存しない。
##
## 場面からアプリへの頼みごと（システムメニューを開く、設定の画面を開く）も、ここの signal を通す
## （場面はアプリを知らなくてよい）。

const MatchChoice := preload("res://game/match_choice.gd")
const Settings := preload("res://game/settings.gd")
const DeckLibrary := preload("res://game/deck_library.gd")
const OverlayStack := preload("res://game/overlay_stack.gd")

## システムメニューを開いてほしい（Esc、何も戻すものが無いとき）。
signal menu_requested
## 設定の画面だけを開いてほしい（タイトルの「設定」）。
signal settings_requested

## 検査として動いているか（空なら、人が遊んでいる）。
const CHECK_AUTOPLAY := &"autoplay"
const CHECK_SHOTS := &"shots"
## 検査で使う対戦の種（毎回同じ対戦にする）。
const CHECK_SEED := 20261114

## 遊ぶ人ごとの設定（設定の画面で変え、user:// に取っておく）。
var settings := Settings.new()
## 取っておいた部隊（編成の画面で組み、対戦の設定で選ぶ。user:// に取っておく）。
var decks := DeckLibrary.new()
## 開いている重なる画面（システムメニュー、ログ、対戦の設定）の積み上げ（overlay_stack.gd）。
## 後ろの場面は、何かが開いているかを、ここだけで見る。Esc と右クリックは、いちばん上の重なる画面だけが受ける。
var overlays := OverlayStack.new()
## システムメニュー（system_menu.gd）。アプリが作って入れる。
var system_menu: Node
## 音を鳴らすところ（sound.gd）。アプリが作って入れる（アプリを通さずに場面を置いたときは無い）。
var sound: Node
## 対戦の設定の場面で選んだもの（match_choice.gd）。対戦の場面は、これで始める。
var match_choice: RefCounted = MatchChoice.new()
## 検査として動いているなら CHECK_AUTOPLAY か CHECK_SHOTS。人が遊んでいるなら空。
var checking := &""


func open_menu() -> void:
	menu_requested.emit()


func open_settings() -> void:
	settings_requested.emit()


## アプリを終える（音を止めて手放してから）。
func quit(code := 0) -> void:
	if sound != null:
		await sound.call(&"release")
	(Engine.get_main_loop() as SceneTree).quit(code)


## 効果音を名前で鳴らす（sound_catalog.gd の EFFECTS。無い名前や、音を鳴らすところが無いときは何もしない）。
func play_sound(name: StringName) -> void:
	if sound != null:
		sound.call(&"play", name)


## 決着の曲を 1 回だけ鳴らす。
func play_jingle(track: StringName) -> void:
	if sound != null:
		sound.call(&"play_jingle", track)


## 場面の曲へ戻す（決着の曲のあと、新しい対戦を始めたとき）。
func resume_scene_music() -> void:
	if sound != null:
		sound.call(&"resume_scene_music")


## 新しい対戦の種。遊ぶときは毎回違う盤面、検査では毎回同じ盤面。
func battle_seed() -> int:
	return CHECK_SEED if checking != &"" else int(Time.get_unix_time_from_system())
