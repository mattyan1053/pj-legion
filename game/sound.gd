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

const Catalog := preload("res://game/sound_catalog.gd")
const Settings := preload("res://game/settings.gd")

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_EFFECTS := &"Effects"
## 曲が替わるときのフェード（秒。消える側と入る側を重ねる）。
const FADE_TIME := 0.8
## 聞こえない大きさ（フェードの端）。
const SILENT_DB := -60.0
## 同時に鳴らせる効果音の数（対戦の中の音が重なっても、鳴っている音を途中で切らない程度）。
const EFFECT_VOICES := 10
## 決着の曲を鳴らすときに、対戦の曲を消す速さ（秒）。ファンファーレは、頭から表の大きさで鳴らす（フェードで入れない）。
const JINGLE_FADE_TIME := 0.4
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
## いま鳴らしている曲の素材（BGM の組を替えたら、同じ名前でも素材が替わる）。
var _track_path := ""
var _scene_track := &""
## いまの曲と場面の曲の、表の大きさからの差（dB。会話の場面で対戦の曲を小さくする。sound_catalog.gd の talk_offset_db）。
var _offset_db := 0.0
var _scene_offset_db := 0.0
## 1 回だけの曲（決着）が鳴り終えたら続ける曲（空なら止まったまま）。
var _then_track := &""
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
	_track_path = ""
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
	Catalog.music_set = settings.value(Settings.MUSIC_SET)
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
## offset_db: 表の大きさからの差（会話の場面で対戦の曲を小さくする）。同じ曲で差だけ違えば、その大きさへフェードする。
func play_scene_music(track: StringName, offset_db := 0.0) -> void:
	_scene_track = track
	_scene_offset_db = offset_db
	play_music(track, offset_db)


## 場面の曲へ戻す（決着の曲のあと、新しい対戦を始めたとき）。
func resume_scene_music() -> void:
	play_music(_scene_track, _scene_offset_db)


## 1 回だけの曲（決着）を鳴らす。いまの曲は短いフェードで消し、ファンファーレは頭から表の大きさで鳴らす。
## 鳴り終えたら then_track（ループの曲）へつなぐ。track が空なら、ファンファーレを鳴らさずに then_track へ。
## 場面の曲は覚えたまま（resume_scene_music で戻る）。
func play_jingle(track: StringName, then_track := &"") -> void:
	_then_track = &""
	if track == &"" or not Catalog.has_music(track):
		play_music(then_track)
		return
	play_music(track, 0.0, true)
	_then_track = then_track


## 決着の曲のあとに続ける曲（鳴らし終えるまで待っている間だけ）。検査用。
func pending_track() -> StringName:
	return _then_track


## 曲 track へ、フェードでつなぐ。空の名前・表に無い名前・素材の無い名前なら、いまの曲を消すだけ。
## 同じ曲が鳴っていれば、鳴らし直さない（場面を行き来しても、曲を頭から鳴らし直さない）。大きさ（offset_db）が違えば、そこへフェードする。
func play_music(track: StringName, offset_db := 0.0, sharp := false) -> void:
	_then_track = &""
	if track == _track and _path_of(track) == _track_path:
		if offset_db != _offset_db and track != &"":
			_offset_db = offset_db
			_fade(_active, _volume_of(track), false)
		return
	var stream := _music_stream(track)
	_track = track if stream != null else &""
	_track_path = _path_of(track) if stream != null else ""
	_offset_db = offset_db
	_fade(_active, SILENT_DB, true, JINGLE_FADE_TIME if sharp else FADE_TIME)
	if stream == null:
		return
	_active = 1 - _active
	# 入る側の再生器に、前のフェード（消えて止まる途中など）が残っていれば止める（決着の曲を、そのフェードが消してしまわないように）。
	if _fades[_active] != null:
		_fades[_active].kill()
		_fades[_active] = null
	var player := _music[_active]
	player.stream = stream
	player.volume_db = _volume_of(track) if sharp else SILENT_DB
	if _audible():
		player.play()
	if not sharp:
		_fade(_active, _volume_of(track), false)


## 曲 track を、いまの差（_offset_db）で鳴らすときの大きさ（dB）。
func _volume_of(track: StringName) -> float:
	return Catalog.music_entry(track).get("volume_db", 0.0) + _offset_db


func _path_of(track: StringName) -> String:
	return Catalog.music_entry(track).get("path", "")


## BGM の組を替えたあと、いまの曲が別の素材になったなら、その素材へフェードでつなぎ直す（オプションで替えて、すぐ聴き比べられるように）。
## 1 回だけの曲（決着）を鳴らしている間は、そのまま（鳴り終えて続ける曲は、新しい組で鳴る）。
func refresh_music() -> void:
	if _track == &"" or _then_track != &"" or not Catalog.music_entry(_track).get("loop", false):
		return
	play_music(_track, _offset_db)


## いまの曲の、表の大きさからの差（dB）。検査用。
func current_offset_db() -> float:
	return _offset_db


## いま鳴らしている曲の名前（止めているか、1 回だけの曲を鳴らし終えたなら空）。検査用。
func current_track() -> StringName:
	return _track


## 1 回だけの曲が終わった。続ける曲があれば、それへ。
func _on_music_finished(slot: int) -> void:
	if slot != _active:
		return
	_track = &""
	_track_path = ""
	var following := _then_track
	_then_track = &""
	if following != &"":
		play_music(following)


## 場面の曲の名前。検査用。
func scene_track() -> StringName:
	return _scene_track


func _music_stream(track: StringName) -> AudioStream:
	if not Catalog.has_music(track):
		return null
	var entry := Catalog.music_entry(track)
	var stream := _load(entry["path"])
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = entry.get("loop", false)
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = entry.get("loop", false)
	return stream


func _fade(slot: int, to_db: float, then_stop: bool, seconds := FADE_TIME) -> void:
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
	tween.tween_property(player, "volume_db", to_db, seconds)
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
