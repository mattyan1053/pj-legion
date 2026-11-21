extends RefCounted
## 場面（scene_flow.gd）どうしで共有するもの。アプリ（app.gd）が 1 つ作り、場面を作るたびに渡す。ノードに依存しない。
##
## 場面からアプリへの頼みごと（システムメニューを開く、オプションの画面を開く）も、ここの signal を通す
## （場面はアプリを知らなくてよい）。

const MatchChoice := preload("res://game/match_choice.gd")
const Settings := preload("res://game/settings.gd")
const DeckLibrary := preload("res://game/deck_library.gd")
const Story := preload("res://game/story.gd")
const OverlayStack := preload("res://game/overlay_stack.gd")
const SaveSlots := preload("res://game/save_slots.gd")

## システムメニューを開いてほしい（Esc、何も戻すものが無いとき）。
signal menu_requested
## オプションの画面だけを開いてほしい（タイトルの「オプション」）。
signal settings_requested
## 流れ（run.gd）を始めてほしい（流れの最初の場面へ切り替える）。
signal run_requested(run: RefCounted)

## 検査として動いているか（空なら、人が遊んでいる）。
const CHECK_AUTOPLAY := &"autoplay"
const CHECK_SHOTS := &"shots"
## 検査で使う対戦の種（毎回同じ対戦にする）。
const CHECK_SEED := 20261114

## 遊ぶ人ごとの設定（オプションの画面で変え、user:// に取っておく）。
var settings := Settings.new()
## 取っておいた部隊（編成の画面で組み、対戦用は対戦設定で、ストーリー用は出撃準備で選ぶ。user:// に取っておく）。
var decks := DeckLibrary.new()
## ストーリーの進み具合（クリアした話。いまのセーブのスロットに取っておく）。
var story := Story.new()
## セーブのスロット（save_slots.gd）。ストーリーの進み具合とストーリー用の部隊は、いまのスロットに書く。
var slots := SaveSlots.new()
## 開いている重なる画面（システムメニュー、ログ、対戦設定）の積み上げ（overlay_stack.gd）。
## 後ろの場面は、何かが開いているかを、ここだけで見る。Esc と右クリックは、いちばん上の重なる画面だけが受ける。
var overlays := OverlayStack.new()
## システムメニュー（system_menu.gd）。アプリが作って入れる。
var system_menu: Node
## 音を鳴らすところ（sound.gd）。アプリが作って入れる（アプリを通さずに場面を置いたときは無い）。
var sound: Node
## 対戦設定の場面で選んだもの（match_choice.gd）。対戦の場面は、これで始める。
var match_choice: RefCounted = MatchChoice.new()
## いま進めている流れ（run.gd）。流れの外の場面にいるときは null。アプリが入れ、流れの外へ出たら捨てる。
var run: RefCounted
## いまの場面の名前（scene_flow.gd の SCENES の鍵）。アプリ（app.gd）が、場面を作る前に入れる。run_data が使う。
var scene := &""
## 検査として動いているなら CHECK_AUTOPLAY か CHECK_SHOTS。人が遊んでいるなら空。
var checking := &""
## 自動の対戦（autoplay.gd）。最初の対戦の場面が作る。2 つ目からの対戦の場面（ストーリーの通し）は、作らない。
var autoplay: Node


func _init() -> void:
	# 取っておいた部隊は、ストーリーの決まり（進み具合で雇える駒が増える）も引ける。進み具合が変わったら引き直す。
	decks.rules_lookup = rules_of
	story.changed.connect(decks.refresh_rules)
	# ストーリーの進み具合とストーリー用の部隊は、いまのスロットに書く（取っておく先の無い検査でも、スロットに覚えておく）。
	slots.open_latest()  # 取っておく先の無いとき（検査）は、空の 1 番。遊ぶときは、アプリが取っておく先を入れてから開き直す
	story.store = slots.section(true)  # 進み具合は覚えておき、区切りで書く（オートセーブ）
	decks.slot_store = slots.section()
	decks.is_slot_rules = is_story_rules


## 決まりの名前が、ストーリーの決まり（どれかの物語の決まり）か。ストーリー用の部隊は、セーブのスロットに書く。
static func is_story_rules(rules_id: StringName) -> bool:
	for each: Story.Campaign in Story.campaigns():
		if each.rules_id == rules_id:
			return true
	return false


## スロット number をいまのスロットにして（空なら新しく始めて）、ストーリーの進み具合と部隊を読み直す。選べたか。
func use_slot(number: int) -> bool:
	if not slots.select(number):
		return false
	reload_slot()
	return true


## いまのスロットの中身で、ストーリーの進み具合と部隊を読み直す（写す・消すで、いまのスロットが変わったとき）。
## 進み具合を先に読む（ストーリー用の部隊は、いま雇える駒の決まりで読む）。
func reload_slot() -> void:
	story.load_saved()
	decks.load_saved()


## 決まりの名前から決まりを引く: ストーリーの決まりは、いまの進み具合のもの。ほかは DeckRules.by_id。
func rules_of(rules_id: StringName) -> DeckRules:
	var rules := story.rules_by_id(rules_id)
	return rules if rules != null else DeckRules.by_id(rules_id)


func open_menu() -> void:
	menu_requested.emit()


func open_settings() -> void:
	settings_requested.emit()


## 流れ a_run を始める（アプリが、いまの場面を抜けて、流れの最初の場面へ切り替える）。
func start_run(a_run: RefCounted) -> void:
	run_requested.emit(a_run)


## いまの場面（scene）に、流れが渡すもの。いまの場面が流れの場面でなければ null（場面は、自分の既定で始める）。
## 場面は自分の名前を書かずに呼ぶ（名前はアプリが入れる。書き間違えて、黙って既定の中身で始まることが無いように）。
func run_data() -> Variant:
	if run == null or run.scene() != scene:
		return null
	return run.data()


## アプリを終える（音を止めて手放してから）。
func quit(code := 0) -> void:
	if sound != null:
		await sound.call(&"release")
	(Engine.get_main_loop() as SceneTree).quit(code)


## 効果音を名前で鳴らす（sound_catalog.gd の EFFECTS。無い名前や、音を鳴らすところが無いときは何もしない）。
func play_sound(name: StringName) -> void:
	if sound != null:
		sound.call(&"play", name)


## 決着の曲を 1 回だけ鳴らし、鳴り終えたら then_track へつなぐ（track が空なら、すぐ then_track へ）。
func play_jingle(track: StringName, then_track := &"") -> void:
	if sound != null:
		sound.call(&"play_jingle", track, then_track)


## 場面の曲を track にする（対戦の画面が、盤の見た目や話で曲を決める）。同じ曲が鳴っていれば、鳴らし直さない。
## offset_db は表の大きさからの差（会話の場面で対戦の曲を小さくする）。
func play_scene_music(track: StringName, offset_db := 0.0) -> void:
	if sound != null:
		sound.call(&"play_scene_music", track, offset_db)


## 場面の曲へ戻す（決着の曲のあと、新しい対戦を始めたとき）。
func resume_scene_music() -> void:
	if sound != null:
		sound.call(&"resume_scene_music")


## 新しい対戦の種。遊ぶときは毎回違う盤面、検査では毎回同じ盤面。
func battle_seed() -> int:
	return CHECK_SEED if checking != &"" else int(Time.get_unix_time_from_system())
