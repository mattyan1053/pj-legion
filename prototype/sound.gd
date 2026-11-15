extends Node
## 音を鳴らすところ（BGM と効果音）。アプリ（app.gd）が 1 つ作り、場面をまたいで持つ（context.sound）。
##
## - 音のバスは 3 つ: Master（全体）の下に Music（BGM）と Effects（効果音）。音量の設定は、ここに掛ける（apply_settings）。
## - BGM は場面ごとに決まる（scene_flow.gd の "music"）。替わるときは短いフェードでつなぎ、同じ曲なら鳴らし直さない。
##   決着の曲（play_jingle）は 1 回だけ鳴らし、resume_scene_music で場面の曲へ戻る。
## - 効果音は名前で鳴らす（play）。表（sound_catalog.gd）に無い名前・素材の無い名前は、黙って何もしない。
## - ボタンの音は、木に入ったボタンへ自分でつなぐ（どの画面のボタンも、何も書かずに鳴る）。
##   ボタンに meta "sound"（効果音の名前）を付けると、その音に替わる。灰色のボタンを押すと「押せない」の音。
## - 音のドライバが無い環境（検査、コンテナ）でも、そのまま動く。画面なしでは、選ぶところまでやって、鳴らさない（_audible）。

const Catalog := preload("res://prototype/sound_catalog.gd")
const Settings := preload("res://prototype/settings.gd")

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_EFFECTS := &"Effects"
## 曲が替わるときのフェード（秒。消える側と入る側を重ねる）。
const FADE_TIME := 0.8
## 聞こえない大きさ（フェードの端）。
const SILENT_DB := -60.0
## 同時に鳴らせる効果音の数（対戦の中の音が重なっても、鳴っている音を途中で切らない程度）。
const EFFECT_VOICES := 10
## アプリを終える前に、止めた音を手放すのを待つ秒数。
const RELEASE_WAIT := 0.1
## ボタンに付ける meta の名前（効果音の名前を入れると、ボタンの音がそれに替わる）。
const BUTTON_SOUND_META := &"sound"

## 2 つの曲の再生器を交互に使う（片方が消える間に、もう片方が入る）。
var _music: Array[AudioStreamPlayer] = []
var _active := 0
var _fades: Array[Tween] = [null, null]
## いま鳴らしている（か、鳴らし終えた）曲の名前と、場面の曲の名前。
var _track := &""
var _scene_track := &""
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
## 名前 -> 最後に鳴らしたフレーム（同じフレームに同じ音を重ねない）。
var _played_frame := {}
## 名前 -> 最後に鳴らした時刻（ミリ秒）。表の gap の間は、同じ音を鳴らし直さない。
var _played_msec := {}
## 弱い音（ボタン）を、フレームの終わりに鳴らすかどうか決めるために待たせている。
var _pending_weak: Array[StringName] = []
## 鳴らした効果音の名前（新しい順に少しだけ。検査用）。
var recent: Array[StringName] = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # メニューで時間を止めても、音は止めない
	ensure_buses()
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_MUSIC
		player.finished.connect(_on_music_finished.bind(i))
		add_child(player)
		_music.append(player)
	for i in EFFECT_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = BUS_EFFECTS
		add_child(voice)
		_voices.append(voice)


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


## アプリを終える前に、鳴らしている音を止めて手放す（終えるのは app_context.gd の quit）。
## 鳴らしたまま終えると、音の再生が後片付けされずに残る（終わるときにエラーが出る）。止めた再生を手放すのは
## 音の側の次の処理なので、少し待ってから返る。
func release() -> void:
	for player: AudioStreamPlayer in _music + _voices:
		player.stop()
		player.stream = null
	_track = &""
	if is_inside_tree():
		await get_tree().create_timer(RELEASE_WAIT, true, false, true).timeout


## バスを作る（もうあれば、そのまま）。
static func ensure_buses() -> void:
	for bus_name: StringName in [BUS_MUSIC, BUS_EFFECTS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, BUS_MASTER)


## 設定の音量を、バスに掛ける。
static func apply_settings(settings: Settings) -> void:
	ensure_buses()
	var muted: bool = settings.value(Settings.MUTE)
	_set_bus(BUS_MASTER, settings.value(Settings.MASTER_VOLUME), muted)
	_set_bus(BUS_MUSIC, settings.value(Settings.MUSIC_VOLUME), false)
	_set_bus(BUS_EFFECTS, settings.value(Settings.EFFECTS_VOLUME), false)


## 音量（0〜100%）を、バスの大きさ（dB）にする。耳に釣り合うよう、割合の 2 乗を掛ける（50% で約 -12 dB）。
static func volume_db(percent: float) -> float:
	var ratio := clampf(percent / 100.0, 0.0, 1.0)
	return linear_to_db(ratio * ratio) if ratio > 0.0 else -INF


static func _set_bus(bus_name: StringName, percent: float, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(index, muted or percent <= 0.0)
	if percent > 0.0:
		AudioServer.set_bus_volume_db(index, volume_db(percent))


# ---- BGM ----


## 場面の曲を track にして鳴らす（空なら止める）。同じ曲が鳴っていれば、鳴らし直さない。
func play_scene_music(track: StringName) -> void:
	_scene_track = track
	play_music(track)


## 場面の曲へ戻す（決着の曲のあと、新しい対戦を始めたとき）。
func resume_scene_music() -> void:
	play_music(_scene_track)


## 1 回だけの曲（決着）を鳴らす。場面の曲は覚えたまま。
func play_jingle(track: StringName) -> void:
	play_music(track)


## 曲 track へ、フェードでつなぐ。空の名前・表に無い名前・素材の無い名前なら、いまの曲を消すだけ。
## 同じ曲が鳴っていれば、何もしない（場面を行き来しても、曲を頭から鳴らし直さない）。
func play_music(track: StringName) -> void:
	if track == _track:
		return
	var stream := _music_stream(track)
	_track = track if stream != null else &""
	_fade(_active, SILENT_DB, true)
	if stream == null:
		return
	_active = 1 - _active
	var player := _music[_active]
	player.stream = stream
	player.volume_db = SILENT_DB
	if _audible():
		player.play()
	_fade(_active, Catalog.MUSIC[track].get("volume_db", 0.0), false)


## いま鳴らしている曲の名前（止めているか、1 回だけの曲を鳴らし終えたなら空）。検査用。
func current_track() -> StringName:
	return _track


## 1 回だけの曲が終わった。
func _on_music_finished(slot: int) -> void:
	if slot == _active:
		_track = &""


## 場面の曲の名前。検査用。
func scene_track() -> StringName:
	return _scene_track


func _music_stream(track: StringName) -> AudioStream:
	if not Catalog.has_music(track):
		return null
	var entry: Dictionary = Catalog.MUSIC[track]
	var stream := _load(entry["path"])
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = entry.get("loop", false)
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = entry.get("loop", false)
	return stream


func _fade(slot: int, to_db: float, then_stop: bool) -> void:
	if _fades[slot] != null:
		_fades[slot].kill()
	var player := _music[slot]
	if not player.playing or not is_inside_tree():
		if then_stop:
			player.stop()
		else:
			player.volume_db = to_db
		return
	var tween := create_tween()
	tween.set_ignore_time_scale(true)  # メニューで止めた時間や、CPU の番の速さに左右されない
	tween.tween_property(player, "volume_db", to_db, FADE_TIME)
	if then_stop:
		tween.tween_callback(player.stop)
	_fades[slot] = tween


# ---- 効果音 ----


## 効果音 name を鳴らす。表に無い名前・素材の無い名前は、何もしない。同じフレームに同じ音は 1 回だけ。
## 表に gap（秒）がある音は、鳴らしてからその間、同じ音をもう鳴らさない（続けて起きる回復・被弾が連打に聞こえないように）。
func play(name: StringName) -> void:
	if not Catalog.has_effect(name):
		return
	var entry: Dictionary = Catalog.EFFECTS[name]
	if entry.get("weak", false):
		if not _pending_weak.has(name):
			_pending_weak.append(name)
			_flush_weak.call_deferred(Engine.get_process_frames())
		return
	_play_now(name)


func _play_now(name: StringName) -> void:
	var frame := Engine.get_process_frames()
	if _played_frame.get(name, -1) == frame:
		return
	var entry: Dictionary = Catalog.EFFECTS[name]
	var now := Time.get_ticks_msec()
	if _played_msec.has(name) and now - int(_played_msec[name]) < int(entry.get("gap", 0.0) * 1000.0):
		return
	var stream := _load(entry["path"])
	if stream == null:
		return
	_played_frame[name] = frame
	_played_msec[name] = now
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = entry.get("volume_db", 0.0)
	if _audible():
		voice.play()
	recent.push_front(name)
	recent.resize(mini(recent.size(), 8))


## 待たせていた弱い音を、同じフレームにほかの音が鳴らなかったときだけ鳴らす。
func _flush_weak(frame: int) -> void:
	var waiting := _pending_weak.duplicate()
	_pending_weak.clear()
	for other: StringName in _played_frame:
		if _played_frame[other] == frame and not Catalog.EFFECTS[other].get("weak", false):
			return
	for name: StringName in waiting:
		_play_now(name)


## 本当に鳴らすか。木に入っていないとき（テスト）と、画面なし（検査、コンテナ）では鳴らさない。
## 画面なしの音のドライバは音を流さないので、止めた再生が片付かずに残り、終わるときにエラーになる。
## 鳴らさないだけで、どの曲・どの音を選ぶかは同じに動く（検査はそれを見る）。
func _audible() -> bool:
	return is_inside_tree() and DisplayServer.get_name() != "headless"


func _load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


# ---- ボタン ----


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		button.pressed.connect(_on_button_pressed.bind(button))
		button.gui_input.connect(_on_button_input.bind(button))
	elif node is Slider:
		# 音量のスライダーを離したら、効果音の大きさを聞けるように 1 つ鳴らす。
		(node as Slider).drag_ended.connect(func(_changed: bool) -> void: play(&"ui_click"))


func _on_button_pressed(button: BaseButton) -> void:
	play(button.get_meta(BUTTON_SOUND_META, &"ui_click"))


func _on_button_input(event: InputEvent, button: BaseButton) -> void:
	if button.disabled and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		play(&"ui_denied")
