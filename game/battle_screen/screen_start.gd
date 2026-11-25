extends "res://game/battle_screen/screen_sides.gd"
## 対戦の場面の始まり: 対戦を作って盤と駒を出す、マップの替え・やり直し、対戦設定のパネル、決着の曲。


## 渡されたもの（source）が作る種 battle_seed の対戦設定で、盤面を作り、軍を置いて、最初から始める。
## 対戦はルールの入口（MatchSetup.create_battle）で作る。相手を CPU が動かすかも、その設定から決める。
## 縫い目の様子（Battle.signs）は、対戦の始めの「対戦ルール」の知らせに、勝利条件と並べて出す。
## 再生の途中と CPU の番の間は何もしない。
func start_battle(battle_seed: int) -> void:
	if is_busy():
		return
	var setup := source.make_setup(battle_seed)
	cpu_opponent = setup.is_cpu(source.cpu_side())
	_show_opponent()
	start_with(setup.create_battle(), source.look(), battle_seed, setup.scenario.title)


## 上の帯の下の、縫い目の様子の札の帯の文（札の名前。出ていなければ空。検査用）。
func signs_text() -> String:
	return _hud.signs_text()


## 上の帯の下の、縫い目の様子の札の i 番目の名前をクリックする（札 1 枚の窓を開く・閉じる）。
func toggle_sign_note(i: int) -> void:
	_hud.toggle_sign_note(i)


func hide_sign_note() -> void:
	_hud.hide_sign_note()


## 開いている札の窓の文（名前と効果。開いていなければ空。検査用）。
func sign_note_text() -> String:
	return _hud.sign_note_text()


## 対戦の始めの知らせを閉じる（閉じるボタンと同じ）。
func hide_notice() -> void:
	_hud.hide_notice()


## CPU の番を進めている途中か（検査用）。
func is_cpu_running() -> bool:
	return _ui.cpu_running


## マップを field（versus_fields.gd の鍵）に替えて、新しい対戦を始める（F1〜F3、決着の画面の「新しいマップ」）。
## 渡されたものが、そのマップを選べない（source.new_board_fields() に無い）なら何もしない。
func start_on_field(field: StringName, battle_seed: int) -> void:
	if is_busy() or not source.new_board_fields().has(field):
		return
	source.choose_field(field)
	start_battle(battle_seed)


## F1〜F3: 「新しいマップ」で選べるマップの index 番目で、新しい対戦を始める（無ければ何もしない）。
func _start_on_nth_field(index: int) -> void:
	var fields := source.new_board_fields()
	if index < fields.size():
		start_on_field(fields[index], map_seed + 1)


## 対戦設定画面を、いまの設定で開く。再生の途中と CPU の番の間は何もしない。
## 開いただけでは、いまの対戦は変わらない（「対戦へ戻る」・右クリック・Esc で、そのまま戻れる）。
## 新しい対戦になるのは、設定画面で始めるボタンを押したときだけ。
## 渡されたものが対戦設定のパネルを開けない（source.can_open_setup() が偽）なら何もしない。
func open_setup() -> void:
	if is_busy() or not source.can_open_setup():
		return
	_setup_panel.open(source, _battle_started, _battle_started and not battle.is_over())


## 対戦設定画面（検査用）。
func setup_panel() -> MatchSetupPanel:
	return _setup_panel


func _on_setup_chosen(chosen: RefCounted) -> void:
	_battle_started = true
	source = chosen
	context.match_choice = chosen.copy()  # 次に対戦設定の場面を開いたときも、これを出す
	# いまの対戦の続きを CPU に渡さないよう、set_opponent は通さない（新しい対戦が、始めに CPU の番を見る）。
	start_battle(map_seed + 1)


## 用意した対戦を、最初から始める（検査では、小さな盤面を作って渡す）。再生の途中と CPU の番の間は何もしない。
## battle_look は盤の見た目の名前（stage_look.gd）、battle_area は決着の画面の「マップ」（空なら出さない）。
func start_with(new_battle: Battle, battle_look: StringName, battle_seed: int, battle_area := "") -> void:
	if is_busy():
		return
	look = battle_look
	area_name = battle_area
	map_seed = battle_seed
	battle = new_battle
	stats = BattleStats.new(battle)
	_phase_focus.clear()
	_log_panel.close()
	# ストーリーなら、陣営を「味方」「敵」と呼ぶ（ログ・上の帯・番の知らせ・マスの説明・決着。names.gd）。
	Names.story_sides = source != null and source.story_sides()
	# 中ボスの名前（話・マップのファイルの boss。無ければ「番人」）。ログ・勝ち方・決着の文の {boss} に入る。
	Names.set_boss(source.boss_name() if source != null else "")
	var names: Array[String] = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		names.append(_side_name(side))
	battle_log = BattleLog.new(battle, names)

	if _board_view != null:
		_board_view.queue_free()
	for view: UnitView in _views.values():
		view.queue_free()
	_views.clear()

	_board_view = BoardView.new()
	add_child(_board_view)
	if _trait_links != null:
		_trait_links.queue_free()
	_trait_links = TraitLinks.new()
	add_child(_trait_links)
	_board_view.setup(battle.board, map_seed, TEAM_COLORS, look)
	_sync_stronghold_flag()  # 途中から見せる対戦でも、旗は確保を進めた陣営の色
	_hud.minimap().show_board(battle.board, look)
	# 場面に入る幕が明けるまでは _process が回らないので、ミニマップの置き場所を先に決めておく（左上に出てから跳ばない）。
	_place_minimap.call_deferred()
	_playback.set_board_view(_board_view)
	StageLook.apply(self, _board_view.look)
	_people = UnitLooks.assign_people(battle.units, source.cast_looks() if source != null else [])
	for unit in battle.units:
		_add_view(unit)

	_rig.fit_board(battle.board.size)  # 見てよい範囲と、引きの上限（小さい盤ほど寄せる）
	_rig.position = _camera_point(Unit.Side.PLAYER1)
	_ui.clear_for_new_battle()
	_playback.skipping = false
	_watch_playback = false
	_auto_side = -1
	# 前の対戦のマウスの下のマス（盤の大きさが違えば、盤の外のマス）と、そこから決めた予測のパネル・メニューの置き場所を持ち越さない。
	# マウスの下のマスは、次のコマで新しい盤から拾い直す（_update_hover）。
	_hover_cell = NO_CELL
	_hover_forced = NO_CELL
	_hud.hide_forecast()
	_layout.clear_forecast()
	_layout.reset_menu()
	_hud.hide_result()
	_hud.result_screen().set_destinations(_new_boards(), source.can_open_setup(), source.can_choose_squad())
	_hud.result_screen().set_leave(Text.t(source.leave()[1]))
	_hud.king_looks = source.king_looks()
	_hud.unit_looks = _people
	_hud.result_screen().king_looks = source.king_looks()
	# 対戦の曲（盤の見た目か、話が決めた曲。battle_source.gd の music）。決着の曲のあとの「やり直す」でも、対戦の曲へ戻る。
	# 新しい盤面で見た目が替われば、曲も替わる。同じ曲なら鳴らし直さない。
	context.play_scene_music(source.music())
	_climax_kings = SoundCatalog.kings_of(battle)
	_climax = false
	_hud.show_signs(battle.signs)
	_cues = source.talk_cues()
	_talk.clear()
	_hud.show_banner(Text.t("battle.banner.phase", {"turn": battle.turn, "side": _side_name(battle.phase)}), TEAM_COLORS[battle.phase])
	_say(_cues.on_start(battle))
	# 対戦の始め（ターン 1）に 1 回だけ、「対戦ルール」（勝利条件と縫い目の様子）を出す。どのモードも（ストーリーは前の会話のあと）。
	# 人が動かす側から見る（人どうしは先手から。対戦モードは両方とも同じ勝ち方）。途中から見せる対戦では出さない。
	var notice: Array[Array] = []
	if battle.turn == 1:
		notice = BattleTexts.rule_cards(battle, _human_side() if cpu_opponent else Unit.Side.PLAYER1)
	_hud.show_notice(notice)
	_refresh()
	_run_cpu()


## 決着の画面が出た。対戦の曲を消して決着の曲を 1 回鳴らし、そのあと静かな曲へつなぐ（渡されたものの after_result_music）。
## 人が勝てば勝ちの曲、CPU に負けたときと引き分けは負けの曲。人どうしは、どちらかが勝っているので勝ちの曲。
## 勝ったときの調子が静か（話のファイルの victory_mood）なら、ファンファーレを鳴らさずに静かな曲へ。
## 渡されたもの（source）が許せば「次へ」を出し、人が勝ったことを知らせる（ストーリーのクリアの記録）。
func _on_result_shown(draw: bool, winner: Unit.Side) -> void:
	_talk.clear()  # 決着の画面に、前の台詞を残さない
	context.play_jingle(result_music(draw, winner, cpu_opponent, _human_side(), source.victory_mood()), source.after_result_music())
	var won := cpu_opponent and not draw and winner == _human_side()
	_hud.result_screen().set_continue(source.can_continue(won), source.retries_on_enter(won))
	# 負けた話は、見出しの下に、話し手のひとこと（話のファイルの [lost]。再戦の手間は増やさない）。
	_hud.result_screen().set_remark([] if won or not cpu_opponent else source.lost_lines())
	source.record_end(battle)
	if won:
		source.record_win(context)


## 決着の曲の名前（sound_catalog.gd の MUSIC）。against_cpu は CPU との対戦か、human_side はそのときの人の側。
## mood は勝ったときの調子（静かなら、勝っても空 = ファンファーレを鳴らさない）。
static func result_music(draw: bool, winner: Unit.Side, against_cpu: bool, human_side: Unit.Side,
		mood := SoundCatalog.MOOD_BRIGHT) -> StringName:
	if draw or (against_cpu and winner != human_side):
		return &"defeat"
	return &"" if mood == SoundCatalog.MOOD_QUIET else &"victory"


func _on_restart_pressed(field: StringName, new_board: bool) -> void:
	if new_board:
		start_on_field(field, map_seed + 1)
	else:
		start_battle(map_seed)


## 決着の画面の「新しいマップ」のボタン: [鍵, 名前] の列。
func _new_boards() -> Array[Array]:
	var boards: Array[Array] = []
	for field in source.new_board_fields():
		boards.append([field, VersusFields.title_of(field)])
	return boards
