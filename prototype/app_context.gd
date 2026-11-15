extends RefCounted
## 場面（scene_flow.gd）どうしで共有するもの。アプリ（app.gd）が 1 つ作り、場面を作るたびに渡す。ノードに依存しない。
##
## 場面からアプリへの頼みごと（システムメニューを開く、設定の画面を開く）も、ここの signal を通す
## （場面はアプリを知らなくてよい）。

const TrialSetup := preload("res://prototype/trial_setup.gd")
const Settings := preload("res://prototype/settings.gd")
const DeckLibrary := preload("res://prototype/deck_library.gd")

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
## システムメニュー（system_menu.gd）。アプリが作って入れる。
var system_menu: Node
## 対戦の設定の場面で選んだもの（trial_setup.gd）。対戦の場面は、これで始める。
var match_choice: RefCounted = TrialSetup.new()
## 検査として動いているなら CHECK_AUTOPLAY か CHECK_SHOTS。人が遊んでいるなら空。
var checking := &""


func open_menu() -> void:
	menu_requested.emit()


func open_settings() -> void:
	settings_requested.emit()


## 新しい対戦の種。遊ぶときは毎回違う盤面、検査では毎回同じ盤面。
func battle_seed() -> int:
	return CHECK_SEED if checking != &"" else int(Time.get_unix_time_from_system())
