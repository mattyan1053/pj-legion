extends "res://game/battle_screen/screen_start.gd"
## 対戦の場面の操作: マスを押す、見る・範囲を表示したまま、駒のそばのメニュー、必殺技・スキル、取り消し、進化先、ターン終了、カメラ、検査用の問い合わせ。


func _unhandled_input(event: InputEvent) -> void:
	if context.overlays.is_open():
		# 開いている間の入力は、重なる画面（メニュー・ログ・対戦設定）が受ける（ここへ届いても、盤面には使わない）。
		# 対戦設定がいちばん上なら、閉じられるときは Esc で閉じる（setup_panel が先に受ける）。閉じられない（起動した直後）なら、メニューを開く。
		var escape: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
		if escape and context.overlays.is_top(_setup_panel):
			open_system_menu()
		return
	if _talk.is_holding():
		# 対戦の途中の台詞を送られるのを待つ間: Enter・Space・クリックで送る（クリックは幕が受ける）。Esc はメニュー。ほかのキーは使わない。
		if event is InputEventKey and event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					advance_talk()
				KEY_ESCAPE:
					press_escape()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			advance_talk()
		return
	if _hud.notice_open():
		# 「対戦ルール」を出している間: クリック・Enter・Space・Esc で閉じるだけ（盤の操作やターン終了にはしない）。視点の操作と右クリックは通す。
		var closing: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE])
		if closing:
			_hud.hide_notice()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 押しただけでは何もしない。離すまでに動かなければクリック、動けば視点を回す・傾ける（駒の上で押したときは、いつもクリック）。
			var cell := _cell_under_mouse()
			_ui.press(event.position, battle.board.in_bounds(cell) and battle.unit_at(cell) != null)
		elif _ui.release():
			click_cell(_cell_at(_ui.press_position))
	elif event is InputEventMouseMotion and _ui.pressing:
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			# ボタンを、帯やメニューの上で離した（離したことが、ここへは届かない）。押していないのに回り続けないよう、やめる。
			_ui.cancel_press()
		elif _ui.drag(event.position):
			_rig.drag(event.relative)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				press_escape()
			KEY_SPACE:
				press_wait()
			KEY_F:
				press_skill()
			KEY_G:
				press_ult()
			KEY_ENTER, KEY_KP_ENTER:
				press_end_turn()
			KEY_1, KEY_KP_1:
				choose_evolution(0)
			KEY_2, KEY_KP_2:
				choose_evolution(1)
			KEY_F1, KEY_F2, KEY_F3:
				_start_on_nth_field(event.physical_keycode - KEY_F1)
			KEY_F4:
				toggle_opponent()
			KEY_T:
				toggle_threat()


## 下の帯の案内（句と印の並び）が、使える幅からはみ出しているか。検査用。
func guide_overflows() -> bool:
	return _hud.guide_overflows()


## 下の帯の案内を 1 行の文にしたもの。検査用。
func guide_text() -> String:
	return _hud.guide_text()


## 上の帯の陣営の欄のうち、幅が足りずに省かれている文（battle_hud.gd）。検査用。
func top_bar_cut_texts() -> Array[String]:
	return _hud.top_bar_cut_texts()


## 進化先の選択肢の枠の四角（出していなければ大きさ 0）。検査用。
func evolution_rect() -> Rect2:
	return _hud.evolution_rect()


## Esc。戻すものがあれば戻す（右クリックと同じ）。何も無ければ（再生の途中や CPU の番も）、システムメニューを開く。
func press_escape() -> void:
	if not cancel():
		open_system_menu()


## システムメニューを開く（右上のボタン、Esc）。いつでも開ける（CPU の番や再生の途中でも）。開くのはアプリ（app.gd）。
## 開いている間は時間を止める（再生も CPU の番も、その場で止まり、閉じると続きから進む）。
func open_system_menu() -> void:
	context.open_menu()


## 画面の駒がいまいるマス（駒の番号 -> マス）。検査用。
func view_cells() -> Dictionary:
	var cells := {}
	for unit_id: int in _views:
		cells[unit_id] = BoardView.cell_of(_views[unit_id].position)
	return cells


## 画面の駒が持っている HP（駒の番号 -> HP。減っていれば、足元の棒に出る）。検査用。
func view_hps() -> Dictionary:
	var hps := {}
	for unit_id: int in _views:
		hps[unit_id] = _views[unit_id].shown_hp
	return hps


## 画面に樽が描かれているマス。検査用。
func barrel_view_cells() -> Array[Vector2i]:
	return _board_view.barrel_cells()


## 画面に描かれている盤の上の効果の番号（小さい順）。検査用。
func field_effect_view_ids() -> Array[int]:
	return _board_view.field_effect_ids()


## 盾の棒に出している残りの耐久（描かれていなければ -1）。検査用。
func barricade_bar_durability(effect_id: int) -> int:
	return _board_view.barricade_durability(effect_id)


## いま出ている結果の見出し（出ていなければ空）。検査用。
func result_title() -> String:
	return _hud.result_title()


## いま出ている詳しい戦績（出ていなければ空）。検査用。
func result_stats() -> String:
	return _hud.result_stats()


## リザルトの画面（result_screen.gd）。検査とスクリーンショットの道具用。
func result_screen() -> Control:
	return _hud.result_screen()


## 盤面のマスをクリックする。選んでいる駒の攻撃できる相手・樽なら攻撃、回復できる味方なら回復、動けるマスなら移動、
## 行動できる自分の駒なら選び直す。ほかの駒（相手、中立、行動を終えた味方）なら、選択はそのままで、その駒を見る（_inspect）。
## 駒のいないマスなら、選ぶのをやめて、そのマスの情報を出す。
## 対象を選んでいる途中（メニューの攻撃・回復・スキル）なら、対象のマスで行動し、ほかの駒なら見て、駒のいないマスでは選ぶのをやめる。
## 駒を見ている間のクリックは見るだけ: ほかの駒なら見る駒を替え、そのほか（駒のいないマス、見ている駒、選んでいる駒）なら見るのをやめて、
## 元の行動の途中へ戻る（移動や攻撃はしない）。
func click_cell(cell: Vector2i) -> void:
	# 盤を触ったら、対戦の始めの知らせは読んだものとする（閉じると手番が始まる。始めの台詞を送るのを待つなら、ここで止まる）。
	_hud.hide_notice()
	if is_busy() or battle.is_over() or not battle.board.in_bounds(cell):
		return
	_hud.hide_sign_note()  # 縫い目の様子の札の窓も閉じる
	_hud.hide_trait_note()  # 部隊の特徴の窓も
	if _ui.confirming_ult or _ui.confirming_auto:
		# 必殺技・おまかせを確かめている途中のクリックは、確かめるのをやめるだけ（移動や攻撃はしない）。
		_ui.confirming_ult = false
		_ui.confirming_auto = false
		_refresh()
		return
	var clicked := battle.unit_at(cell)
	if _ui.inspected_id != 0:
		if clicked == null or clicked.id == _ui.inspected_id or clicked.id == _ui.selected_id:
			_inspect(0)
		elif _can_select(clicked) and battle.acting_unit_id == 0 and _ui.mode == Mode.NONE:
			_select(clicked.id)
		else:
			_inspect(clicked.id)
		return
	# 選んでいる駒のほかの駒で、行動の相手にならないもの（見るだけ）。
	var other := clicked != null and clicked.id != _ui.selected_id
	if _ui.mode == Mode.SKILL:
		if _skill_cells.has(cell):
			_do(UseSkillAction.new(_ui.selected_id, cell))
		elif other:
			_inspect(clicked.id)
		else:
			_leave_mode()
		return
	if clicked != null and _targets.has(clicked) and _ui.mode != Mode.HEAL:
		_do(AttackAction.new(_ui.selected_id, clicked.id))
	elif clicked != null and _heal_targets.has(clicked) and _ui.mode != Mode.ATTACK:
		_do(HealAction.new(_ui.selected_id, clicked.id))
	elif _barrel_targets.has(cell) and _ui.mode != Mode.HEAL:
		_do(AttackBarrelAction.new(_ui.selected_id, cell))
	elif _barricade_targets.has(cell) and _ui.mode != Mode.HEAL:
		_do(AttackBarricadeAction.new(_ui.selected_id, cell))
	elif other and (_ui.mode != Mode.NONE or battle.acting_unit_id != 0 or not _can_select(clicked)):
		_inspect(clicked.id)
	elif _ui.mode != Mode.NONE:
		_leave_mode()
	elif _move_cells.has(cell):
		_do(MoveAction.new(_ui.selected_id, cell, _move_cells[cell]))  # 転移のあとなら、残りの移動力で続けて動く
	elif battle.acting_unit_id != 0:
		pass  # 動いたあとは、攻撃・回復・待機・取り消しのどれかを選ぶ。
	else:
		_select(clicked.id if clicked != null else 0)
		if clicked == null:
			_ui.inspected_cell = cell
			_refresh()


## その駒を、行動させる駒として選べるか（いまの番の人のプレイヤーの、行動できる駒）。選べない駒は、クリックすると見るだけ。
func _can_select(unit: Unit) -> bool:
	return unit != null and unit.side == battle.phase and not _is_cpu_turn() and battle.can_act(unit)


## 駒を見る（閲覧）。選んでいる駒、動いたあとの状態、対象を選ぶ途中は、そのまま残す。0 なら見るのをやめる。
func _inspect(unit_id: int) -> void:
	_ui.inspect(unit_id)
	_refresh()


## 敵の全員の脅威範囲を出す・消す（下の帯の切り替え、T）。いつでも切り替えられ、出したままにできる。
func toggle_threat() -> void:
	_threat_shown = not _threat_shown
	if not _ui.busy:
		_refresh()


## 駒 unit_id（見ている相手の駒）の攻撃範囲を、表示したままにする・やめる（情報の枠のスイッチ）。
## 盤を見ている人のプレイヤーの駒は留めない。
func toggle_pin(unit_id: int) -> void:
	var unit := battle.unit_by_id(unit_id)
	if unit == null or not _can_pin(unit):
		return
	_ui.toggle_pin(unit_id)
	context.play_sound(&"ui_confirm")
	if not _ui.busy:
		_refresh()


## 範囲を表示したままにしている駒の番号（留めた順）と、盤に出している範囲（駒ごとのマスの列）。検査用。
func pinned_ids() -> Array[int]:
	return _ui.pinned_ids.duplicate()


func pinned_sets() -> Array:
	return _board_view.pinned_sets()


## 情報の枠の「範囲を表示したまま」のスイッチ: [出ているか, 入っているか]。press_pin_switch で押す。検査用。
func pin_switch_state() -> Array[bool]:
	return _hud.pin_switch_state()


func press_pin_switch() -> bool:
	return _hud.press_pin_switch()


## 敵の全員の脅威範囲を出しているか。検査用。
func is_threat_shown() -> bool:
	return _threat_shown


## 盤に重ねて出している、敵の全員の脅威範囲のマス（出していなければ空）。検査用。
func threat_overlay_cells() -> Array[Vector2i]:
	return _board_view.danger_cells()


## 見ている・選んでいる駒の脅威範囲として、塗っているマス（薄い赤）。検査用。
func threat_painted_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _painted:
		if _painted[cell] == COLOR_THREAT:
			cells.append(cell)
	return cells


## 駒のそばのメニューの項目を押す（クリックと同じ道を通る）。出ていて押せる項目なら真を返す。
func press_menu(id: StringName) -> bool:
	return not is_busy() and _hud.press_menu(id)


func _on_menu_pressed(id: StringName) -> void:
	if is_busy() or battle.is_over() or _ui.selected_id == 0:
		return
	_ui.focus_selected()  # メニューを押したら、見るのをやめて、選んでいる駒の行動へ戻る
	match id:
		MENU_ATTACK:
			_enter_mode(Mode.ATTACK)
		MENU_HEAL:
			_enter_mode(Mode.HEAL)
		MENU_SKILL:
			if not _skill_cells.is_empty():
				_enter_mode(Mode.SKILL)
		MENU_WAIT:
			_do(WaitAction.new(_ui.selected_id))
		MENU_UNDO:
			if battle.acting_unit_id != 0:
				_do(UndoMoveAction.new(battle.acting_unit_id))
		MENU_BACK:
			_leave_mode()
		MENU_WARP:
			press_warp()


func _on_menu_hovered(id: StringName) -> void:
	_ui.menu_hover_id = id
	if not _ui.busy:
		_update_info()


func _enter_mode(mode: BattleUiState.Mode) -> void:
	_ui.mode = mode
	_refresh()


func _leave_mode() -> void:
	_ui.mode = Mode.NONE
	_refresh()


## 選んでいる駒を、いまのポータルから対のポータルへ転移させる（メニューの「転移」。WarpAction）。
## 移動力が残っていれば、転移した先から続けて動ける（範囲を塗り直す）。
func press_warp() -> void:
	if is_busy() or _ui.selected_id == 0 or _warp == NO_CELL:
		return
	_do(WarpAction.new(_ui.selected_id))


## 選んでいる駒を待機させる（メニューの「待機」）。
func press_wait() -> void:
	press_menu(MENU_WAIT)


## 選んでいる駒のスキルの対象を選び始める（メニューのスキルの項目）。もう選んでいる途中なら、やめる（メニューの「やめる」）。
func press_skill() -> void:
	press_menu(MENU_BACK if _ui.mode == Mode.SKILL else MENU_SKILL)


## いまの番のプレイヤーの必殺技を使う。対象を選ばず、取り消せないので、1 回目は確かめるだけで、もう一度押すと使う。
## ゲージがいっぱいでなければ何もしない。駒を選んでいなくても、駒が行動の途中でも使える。
func press_ult() -> void:
	if is_busy() or not battle.can_apply(UseUltAction.new()):
		return
	if not _ui.confirming_ult:
		_ui.start_confirming_ult(Time.get_ticks_msec())
		_refresh()
		return
	if _ui.confirm_guarded(Time.get_ticks_msec()):
		return  # 確かめに変わった直後の 2 回目（ダブルクリック・連打）は受けない
	_do(UseUltAction.new())


## 必殺技を使うかを確かめている途中か。検査用。
func is_confirming_ult() -> bool:
	return _ui.confirming_ult


## 必殺技のボタンに出している文字と、押せるか。上の帯のゲージの文字。検査用。
func ult_button_text() -> String:
	return _hud.ult_button_text()


func is_ult_enabled() -> bool:
	return _hud.is_ult_enabled()


func ult_gauge_text(player: int) -> String:
	return _hud.ult_gauge_text(player)


## 上の帯に出ている、陣営の聖遺物の文字（持っていなければ空）。検査用。
func relic_text(player: int) -> String:
	return _hud.relic_text(player)


## スキルの対象を選んでいる途中か。検査用。
func is_choosing_skill_target() -> bool:
	return _ui.mode == Mode.SKILL


## 攻撃・回復の相手を選んでいる途中か（メニューの「攻撃」「回復」を押したあと）。検査用。
func is_choosing_target() -> bool:
	return _ui.mode == Mode.ATTACK or _ui.mode == Mode.HEAL


## メニューのスキルの項目に出している文字と、押せるか。検査用。
func skill_button_text() -> String:
	return _hud.menu_text(MENU_SKILL)


func is_skill_enabled() -> bool:
	return _hud.is_menu_enabled(MENU_SKILL)


## 駒のそばのメニューに出ている項目の名前（上から）と、画面に占める四角、置いてよい範囲。検査用。
func menu_ids() -> Array[StringName]:
	return _hud.menu_ids()


func menu_rect() -> Rect2:
	_layout.place_menu(selected_unit(), _painted)
	return _hud.menu_rect()


## メニューが届くマス（青・黄）に掛かっているか。検査用。
func menu_covers_move() -> bool:
	_layout.place_menu(selected_unit(), _painted)
	return _layout.menu_covers_move()


func menu_area() -> Rect2:
	return _hud.menu_area()


## マスの中央が画面に出る位置（px）。検査とスクリーンショットの道具用。
func cell_screen_position(cell: Vector2i) -> Vector2:
	return _rig.camera.unproject_position(BoardView.cell_center(cell))


## カメラの向き（回していく先。ラジアン）。検査用。
func camera_yaw() -> float:
	return _rig.target_yaw()


## カメラの見下ろす角度（傾けていく先。度）。検査用。
func camera_pitch() -> float:
	return _rig.target_pitch()


## カメラの見下ろす角度を pitch（度）にする（範囲に収める）。スクリーンショットの道具用。
func set_camera_pitch(pitch: float) -> void:
	_rig.set_pitch(pitch)


## カメラの距離と向き（度）を決める。スクリーンショットの道具用。
func set_camera_view(distance: float, yaw_degrees: float) -> void:
	_rig.set_view(distance, yaw_degrees)


## カメラを、すぐに point を中央に見る位置へ置く（追うのをやめる）。スクリーンショットの道具用。
func place_camera(point: Vector3) -> void:
	_rig.place_at(point)


## 駒のそばのメニューと予測のパネルを、いまのカメラだけで置き直す（前に選んだ側をひいきしない）。スクリーンショットの道具用。
func replace_panels() -> void:
	_layout.reset_placement()


## カメラがいま見ている地点（盤面の上）。スクリーンショットの道具用。
func camera_center() -> Vector3:
	return _rig.position


## ドラッグの感度と、縦のドラッグを逆にしているか（設定が効いているかを見る）。検査用。
func camera_drag_settings() -> Array:
	return [_rig.drag_sensitivity, _rig.invert_vertical]


## 画面の中央の知らせ（番の知らせなど）が出ているか。スクリーンショットの道具用。
func is_banner_shown() -> bool:
	return _hud.is_banner_shown()


## メニューの項目 id にマウスを乗せたことにする（空なら、離したことにする）。検査とスクリーンショットの道具用。
func hover_menu_item(id: StringName) -> void:
	_on_menu_hovered(id)


## 盤面への入力を、マウスやキーと同じ道で渡す。検査用。
func feed_input(event: InputEvent) -> void:
	_unhandled_input(event)


## cell に、見ている駒の白い輪を出す（駒がいなくても）。スクリーンショットの道具用。
func mark_cell(cell: Vector2i) -> void:
	_inspect_ring.position = BoardView.cell_center(cell) + Vector3(0.0, 0.04, 0.0)
	_inspect_ring.visible = true


## 画面を通さずに起きたこと events（対戦の始めから）を数えて、side の番の始めにカメラが寄る駒を返す。スクリーンショットの道具用。
func phase_focus_after(events: Array[BattleEvent], side: Unit.Side) -> Unit:
	_phase_focus.feed(battle, events)
	return _phase_focus.unit_for(battle, side)


## 左下の情報の枠に出ている文（見出しを除く）。検査用。
func info_text() -> String:
	return _hud.info_text()


## 左下の情報の枠の見出し（出ていなければ空）。検査用。
func info_title() -> String:
	return _hud.info_title()


## 戻す（右クリック・Esc）。必殺技を確かめている途中か、対象を選んでいる途中なら、それをやめる。
## 動いたあとなら移動を取り消す。そうでなければ選択をやめる（マスの情報も消す）。ターン終了の確かめも、やめる。
## 戻したものがあったかを返す（無ければ、Esc はシステムメニューを開く）。戻したら、戻す音を鳴らす。
func cancel() -> bool:
	var done := _cancel()
	if done:
		context.play_sound(&"ui_back")
	return done


func _cancel() -> bool:
	if is_busy():
		return false
	match _ui.back(battle.acting_unit_id != 0):
		BattleUiState.Back.DONE:
			_refresh()
		BattleUiState.Back.UNDO_MOVE:
			_do(UndoMoveAction.new(battle.acting_unit_id))
		BattleUiState.Back.DESELECT:
			_select(0)
		BattleUiState.Back.UNPIN_ALL:
			_refresh()
		_:
			return false
	return true


## 進化先を選ぶ（index は選択肢の何番目か）。進化先を選ぶのを待っている駒がいるときだけ。
func choose_evolution(index: int) -> void:
	if is_busy() or battle.is_over():
		return
	var unit := battle.evolving_unit()
	if unit == null:
		return
	var choices := battle.options(unit.id).evolutions
	if index >= 0 and index < choices.size():
		_do(EvolveAction.new(unit.id, choices[index]))


## 進化先の選択肢を出しているか。検査用。
func is_choosing_evolution() -> bool:
	return _hud.is_evolution_shown()


## ターンを終える。未行動の駒が残っていれば、もう一度押すまで終えない。進化先を選ぶ途中は終えられない。
## 確かめに変わった直後の 2 回目（ダブルクリック・Enter の連打）は受けない（BattleUiState.CONFIRM_GUARD_MSEC）。
func press_end_turn() -> void:
	if is_busy() or battle.is_over() or battle.evolving_unit() != null:
		return
	if Queries.unacted_count(battle) > 0:
		if not _ui.confirming_end:
			_ui.start_confirming_end(Time.get_ticks_msec())
			_refresh()
			return
		if _ui.confirm_guarded(Time.get_ticks_msec()):
			return
	_do(EndPhaseAction.new())


## 確かめを始めた直後の、2 回目を受けない間を、もう過ぎたことにする。検査用（人が間を置いてもう一度押すのと同じ）。
func pass_confirm_guard() -> void:
	_ui.confirm_started_msec -= BattleUiState.CONFIRM_GUARD_MSEC


## ターン終了を確かめている途中か。検査用。
func is_confirming_end() -> bool:
	return _ui.confirming_end
