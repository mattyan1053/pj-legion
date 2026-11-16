extends "res://tests/base_test.gd"
## 音（game/sound.gd、game/sound_catalog.gd）: 場面ごとの BGM、曲のつなぎ、効果音の入口、音量の設定。
## 検査は音の出ないドライバで動く。鳴っているかは、再生器の状態で見る。

const Sound := preload("res://game/sound.gd")
const Catalog := preload("res://game/sound_catalog.gd")
const SceneFlow := preload("res://game/scene_flow.gd")
const Settings := preload("res://game/settings.gd")
const SaveStore := preload("res://game/save_store.gd")
const BattleScreen := preload("res://game/battle_screen.gd")
const BattleEffects := preload("res://game/battle_effects.gd")
const StageLook := preload("res://game/stage_look.gd")
const MatchChoice := preload("res://game/match_choice.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const Story := preload("res://game/story.gd")
const VersusFields := preload("res://game/versus_fields.gd")


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


func test_each_look_has_its_battle_music() -> void:
	var tracks := {}
	for look_name: StringName in StageLook.THEMES:
		var track := Catalog.battle_music(look_name)
		assert_true(Catalog.has_music(track), "%s の対戦の曲 %s が表にある" % [look_name, track])
		assert_true(Catalog.MUSIC[track]["loop"], "対戦の曲はループする（%s）" % track)
		tracks[track] = true
	assert_eq(tracks.size(), StageLook.THEMES.size(), "見た目ごとに違う曲")
	for look_name: StringName in Catalog.LOOK_MUSIC:
		assert_true(StageLook.THEMES.has(look_name), "LOOK_MUSIC の鍵は見た目の名前（%s）" % look_name)
	assert_eq(Catalog.battle_music(&"no_such_look"), &"battle", "知らない見た目は、いつもの対戦の曲")


func test_versus_battle_plays_the_music_of_its_look() -> void:
	for field: StringName in VersusFields.all_ids():
		var choice := MatchChoice.new()
		choice.field = field
		var expected := Catalog.battle_music(VersusFields.look_of(field))
		assert_eq(choice.music(), expected, "%s の対戦の曲" % field)
		assert_eq(SceneFlow.music_for(SceneFlow.BATTLE, choice), expected, "対戦の場面へ入るときから、その曲")


func test_story_music_comes_from_the_episode() -> void:
	for episode: Script in Story.EPISODES:
		var battle := StoryBattle.new(episode, null)
		var track := battle.music()
		assert_true(Catalog.has_music(track), "%s の対戦の曲 %s が表にある" % [episode.ID, track])
		if not episode.get_script_constant_map().has(&"MUSIC"):
			assert_eq(track, Catalog.battle_music(episode.LOOK), "%s: MUSIC が無ければ、盤の見た目の曲" % episode.ID)
		var talk := Story.talk_of(episode, episode.BEFORE)
		var talk_track := SceneFlow.music_for(SceneFlow.TALK, talk)
		assert_true(Catalog.has_music(talk_track), "%s の会話の曲 %s が表にある" % [episode.ID, talk_track])
		if not episode.get_script_constant_map().has(&"TALK_MUSIC"):
			assert_eq(talk_track, &"talk", "%s: TALK_MUSIC が無ければ、会話の場面の曲" % episode.ID)
	var hold: Script = load("res://game/episodes/ridge_hold.gd")
	assert_eq(StoryBattle.new(hold, null).music(), &"battle_tense", "守り切る話は、緊迫した曲")


func test_music_for_falls_back_to_the_scene_table() -> void:
	assert_eq(SceneFlow.music_for(SceneFlow.TITLE, null), &"menu")
	assert_eq(SceneFlow.music_for(SceneFlow.TALK, {"music": &""}), &"talk", "空の名前なら、場面の表の曲")
	assert_eq(SceneFlow.music_for(SceneFlow.TALK, {"music": &"battle_tense"}), &"battle_tense")
	assert_eq(SceneFlow.music_for(SceneFlow.SORTIE, {"episode": null}), &"menu", "曲を決めない渡すもの")


func test_new_board_with_another_look_changes_the_music() -> void:
	var sound := _sound()
	sound.play_scene_music(Catalog.battle_music(StageLook.GRASSLAND))
	var player: AudioStreamPlayer = sound._music[sound._active]
	sound.play_scene_music(Catalog.battle_music(StageLook.GRASSLAND))
	assert_true(sound._music[sound._active] == player, "同じ見た目でやり直すなら、鳴らし直さない")
	sound.play_scene_music(Catalog.battle_music(StageLook.CRYSTAL_FOREST))
	assert_eq(sound.current_track(), &"battle_crystal")
	assert_eq(sound.scene_track(), &"battle_crystal", "決着の曲のあとは、この曲へ戻る")
	_drop(sound)


func test_result_music_is_played_once() -> void:
	for track: StringName in [&"victory", &"defeat"]:
		assert_true(Catalog.has_music(track), String(track))
		assert_false(Catalog.MUSIC[track]["loop"], "決着の曲は 1 回だけ（%s）" % track)


func test_every_listed_sound_has_its_file() -> void:
	assert_eq(Catalog.missing_files(), [] as Array[String])


func test_result_music_follows_who_won() -> void:
	var p1 := Unit.Side.PLAYER1
	var p2 := Unit.Side.PLAYER2
	assert_eq(BattleScreen.result_music(false, p1, true, p1), &"victory", "CPU に勝った")
	assert_eq(BattleScreen.result_music(false, p1, true, p2), &"defeat", "CPU に負けた（人は後手）")
	assert_eq(BattleScreen.result_music(false, p2, false, p1), &"victory", "人どうしは、どちらかが勝っている")
	assert_eq(BattleScreen.result_music(true, Unit.Side.NEUTRAL, true, p1), &"defeat", "引き分け")


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


func test_gap_keeps_the_same_sound_from_repeating() -> void:
	var sound := _sound()
	assert_true(Catalog.EFFECTS[&"heal"].get("gap", 0.0) > 0.0, "回復の音には間がある")
	sound.play(&"heal")
	sound._played_frame.clear()  # 次のフレームのつもり
	sound.play(&"heal")
	assert_eq(sound.recent, [&"heal"] as Array[StringName], "間の中では、同じ音を鳴らし直さない")
	sound.play(&"critical")
	assert_eq(sound.recent[0], &"critical", "ほかの音は鳴る")
	sound._played_frame.clear()
	sound._played_msec.clear()  # 間が過ぎたつもり
	sound.play(&"heal")
	assert_eq(sound.recent[0], &"heal", "間が過ぎれば、また鳴る")
	_drop(sound)


func test_battle_sounds_cover_every_style_and_skill() -> void:
	for style: int in BattleEffects.Style.values():
		assert_true(Catalog.has_effect(BattleEffects.STYLE_SOUNDS[style]), "当たり方 %d の音" % style)
	for skill: int in Skill.Id.values():
		assert_true(BattleEffects.SKILL_SOUNDS.has(skill), "スキル %d に音がある" % skill)
		assert_true(Catalog.has_effect(BattleEffects.SKILL_SOUNDS[skill]), "スキル %d の音が表にある" % skill)


## 画面の側（game/）のコードが名前で鳴らす効果音（play_sound(&"…")、_sound(&"…")）は、どれも表にある（書き間違えると黙って鳴らないため）。
func test_every_sound_name_in_the_code_is_listed() -> void:
	var pattern := RegEx.create_from_string("(?:play_sound|_sound|Sound\\.play)\\(&\"([a-z_0-9]+)\"\\)")
	var found := 0
	for file in DirAccess.get_files_at("res://game"):
		if not file.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string("res://game".path_join(file))
		for m in pattern.search_all(text):
			found += 1
			assert_true(Catalog.has_effect(StringName(m.get_string(1))), "%s の %s が表にある" % [file, m.get_string(1)])
	assert_true(found >= 15, "対戦の音を名前で鳴らしている（%d か所）" % found)
