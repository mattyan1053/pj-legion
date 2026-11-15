extends "res://tests/base_test.gd"
## 音（prototype/sound.gd、prototype/sound_catalog.gd）: 場面ごとの BGM、曲のつなぎ、効果音の入口、音量の設定。
## 検査は音の出ないドライバで動く。鳴っているかは、再生器の状態で見る。

const Sound := preload("res://prototype/sound.gd")
const Catalog := preload("res://prototype/sound_catalog.gd")
const SceneFlow := preload("res://prototype/scene_flow.gd")
const Settings := preload("res://prototype/settings.gd")
const SaveStore := preload("res://prototype/save_store.gd")
const BoardPrototype := preload("res://prototype/board_prototype.gd")


## 木に入れずに使う（テストはフレームを進めないので、鳴らすところまでは行かず、選んだ曲と音を見る）。
func _sound() -> Sound:
	return Sound.new()


func _drop(sound: Sound) -> void:
	sound.free()


func test_each_scene_has_its_music() -> void:
	assert_eq(SceneFlow.music(&"title"), &"menu")
	assert_eq(SceneFlow.music(&"decks"), &"menu", "タイトルから編成・対戦の設定までは同じ曲（途切れない）")
	assert_eq(SceneFlow.music(&"setup"), &"menu")
	assert_eq(SceneFlow.music(&"battle"), &"battle")
	assert_eq(SceneFlow.music(&"nowhere"), &"")
	for scene: StringName in SceneFlow.SCENES:
		var track := SceneFlow.music(scene)
		assert_true(Catalog.has_music(track), "%s の曲 %s が表にある" % [scene, track])
		assert_true(Catalog.MUSIC[track]["loop"], "場面の曲はループする（%s）" % track)


func test_result_music_is_played_once() -> void:
	for track: StringName in [&"victory", &"defeat"]:
		assert_true(Catalog.has_music(track), String(track))
		assert_false(Catalog.MUSIC[track]["loop"], "決着の曲は 1 回だけ（%s）" % track)


func test_every_listed_sound_has_its_file() -> void:
	assert_eq(Catalog.missing_files(), [] as Array[String])


func test_result_music_follows_who_won() -> void:
	var p1 := Unit.Side.PLAYER1
	var p2 := Unit.Side.PLAYER2
	assert_eq(BoardPrototype.result_music(false, p1, true, p1), &"victory", "CPU に勝った")
	assert_eq(BoardPrototype.result_music(false, p1, true, p2), &"defeat", "CPU に負けた（人は後手）")
	assert_eq(BoardPrototype.result_music(false, p2, false, p1), &"victory", "人どうしは、どちらかが勝っている")
	assert_eq(BoardPrototype.result_music(true, Unit.Side.NEUTRAL, true, p1), &"defeat", "引き分け")


func test_same_music_is_not_restarted() -> void:
	var sound := _sound()
	sound.play_scene_music(&"menu")
	assert_eq(sound.current_track(), &"menu")
	var player: AudioStreamPlayer = sound._music[sound._active]
	sound.play_scene_music(&"menu")
	assert_true(sound._music[sound._active] == player, "同じ曲なら、同じ再生器のまま（鳴らし直さない）")
	sound.play_scene_music(&"battle")
	assert_eq(sound.current_track(), &"battle")
	assert_true(sound._music[sound._active] != player, "曲が替わると、もう片方の再生器で入ってくる（フェードでつなぐ）")
	_drop(sound)


func test_jingle_then_back_to_the_scene_music() -> void:
	var sound := _sound()
	sound.play_scene_music(&"battle")
	sound.play_jingle(&"victory")
	assert_eq(sound.current_track(), &"victory")
	assert_eq(sound.scene_track(), &"battle", "決着の曲の間も、場面の曲は覚えている")
	sound.resume_scene_music()
	assert_eq(sound.current_track(), &"battle")
	_drop(sound)


func test_unknown_names_do_nothing() -> void:
	var sound := _sound()
	sound.play_scene_music(&"menu")
	sound.play_music(&"no_such_track")
	assert_eq(sound.current_track(), &"", "知らない曲なら、いまの曲を消すだけ")
	sound.play(&"no_such_sound")
	assert_eq(sound.recent, [] as Array[StringName], "表に無い効果音は鳴らさない")
	_drop(sound)


func test_effects_play_by_name_once_per_frame() -> void:
	var sound := _sound()
	sound.play(&"ui_confirm")
	sound.play(&"ui_confirm")
	sound.play(&"ui_back")
	assert_eq(sound.recent, [&"ui_back", &"ui_confirm"] as Array[StringName], "同じフレームの同じ音は 1 回")
	_drop(sound)


func test_button_click_gives_way_to_other_sounds() -> void:
	var sound := _sound()
	var frame := Engine.get_process_frames()
	sound.play(&"ui_click")
	sound.play(&"menu_open")
	sound._flush_weak(frame)
	assert_eq(sound.recent, [&"menu_open"] as Array[StringName], "メニューを開いた音が鳴るなら、ボタンの音は譲る")
	sound.play(&"ui_click")
	sound._played_frame.clear()
	sound._flush_weak(frame)
	assert_eq(sound.recent[0], &"ui_click", "ほかに鳴らなければ、ボタンの音を鳴らす")
	_drop(sound)


func test_volume_settings_reach_the_buses() -> void:
	var settings := Settings.new()
	Sound.apply_settings(settings)
	var master := AudioServer.get_bus_index(Sound.BUS_MASTER)
	var music := AudioServer.get_bus_index(Sound.BUS_MUSIC)
	var effects := AudioServer.get_bus_index(Sound.BUS_EFFECTS)
	assert_true(music > 0 and effects > 0, "BGM と効果音のバスがある")
	assert_eq(AudioServer.get_bus_send(music), Sound.BUS_MASTER)
	assert_eq(AudioServer.get_bus_send(effects), Sound.BUS_MASTER)
	settings.set_value(Settings.MUSIC_VOLUME, 50)
	Sound.apply_settings(settings)
	assert_between(AudioServer.get_bus_volume_db(music), -12.1, -11.9, "50% は約 -12 dB")
	settings.set_value(Settings.EFFECTS_VOLUME, 0)
	Sound.apply_settings(settings)
	assert_true(AudioServer.is_bus_mute(effects), "0% は消す")
	settings.set_value(Settings.MUTE, true)
	Sound.apply_settings(settings)
	assert_true(AudioServer.is_bus_mute(master), "音を消すと、全体を消す")
	settings.reset_all()
	Sound.apply_settings(settings)
	assert_false(AudioServer.is_bus_mute(master))
	assert_false(AudioServer.is_bus_mute(effects))
	assert_eq(Sound.volume_db(100), 0.0)


func test_volume_settings_are_saved() -> void:
	var store := SaveStore.new("user://test_sound_%d" % (Time.get_ticks_usec() + randi()))
	var settings := Settings.new()
	settings.store = store
	settings.set_value(Settings.MASTER_VOLUME, 55)
	settings.set_value(Settings.MUSIC_VOLUME, 20)
	settings.set_value(Settings.EFFECTS_VOLUME, 35)
	settings.set_value(Settings.MUTE, true)
	assert_true(settings.save())
	var again := Settings.new()
	again.store = store
	again.load_saved()
	assert_eq(again.value(Settings.MASTER_VOLUME), 55)
	assert_eq(again.value(Settings.MUSIC_VOLUME), 20)
	assert_eq(again.value(Settings.EFFECTS_VOLUME), 35)
	assert_eq(again.value(Settings.MUTE), true)
	for file in DirAccess.get_files_at(store.dir):
		DirAccess.remove_absolute(store.dir.path_join(file))
	DirAccess.remove_absolute(store.dir)
