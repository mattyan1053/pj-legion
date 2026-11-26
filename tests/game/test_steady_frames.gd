extends "res://tests/base_test.gd"
## 枠の大きさは中身で変えない（docs/ui-theme.md の「枠の大きさ」）。
## - 枠の見張り（game/steady_probe.gd）が、印の付いた枠（game/steady.gd）の伸び縮みを拾うこと。
## - 中身を次々替えても大きさが変わらない部品を、1 つずつ。自動の対戦では通りにくい中身（全部の駒、いちばん長い文）を当てる。

const Steady := preload("res://game/steady.gd")
const SteadyProbe := preload("res://game/steady_probe.gd")
const DeployNote := preload("res://game/deploy_note.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const BattleHud := preload("res://game/battle_hud.gd")
const KeyMarks := preload("res://game/key_marks.gd")
const Palette := preload("res://game/ui_palette.gd")
const BattleTexts := preload("res://game/battle_texts.gd")
const Names := preload("res://game/names.gd")
const Text := preload("res://game/text.gd")
const CpuGame := preload("res://tests/support/cpu_game.gd")
const Story := preload("res://game/story.gd")
const TalkScreen := preload("res://game/talk_screen.gd")
const BattleTalk := preload("res://game/battle_talk.gd")
const ResultScreen := preload("res://game/result_screen.gd")
const ResultSummary := preload("res://game/result_summary.gd")
const TraitTag := preload("res://game/trait_tag.gd")
const TraitSentence := preload("res://game/trait_sentence.gd")
const TraitCard := preload("res://game/trait_card.gd")
const DeckPreview := preload("res://game/deck_preview.gd")
const DeckBase := preload("res://game/deck_screen/deck_base.gd")
const SortieScreen := preload("res://game/sortie_screen.gd")


func _frames(count: int) -> void:
	for i in count:
		await (Engine.get_main_loop() as SceneTree).process_frame


## 印の付いた板と、その中の文。
func _marked(what: String, kind: StringName) -> Array:
	var panel := PanelContainer.new()
	Steady.mark(panel, what, kind)
	var label := Label.new()
	label.text = "短い"
	panel.add_child(label)
	return [panel, label]


## わざと動く枠: 文を長くすると板が伸びる。見張りが拾う。
func test_probe_catches_a_frame_that_follows_its_text() -> void:
	var probe := SteadyProbe.new()
	await settle(probe)
	var made := _marked("試し: 伸びる板", Steady.SIZE)
	await settle(made[0])
	await _frames(3)
	assert_eq(probe.report(), "", "動いていないのに拾った")
	made[1].text = "長い文にすると、板が横へ伸びる"
	await _frames(4)
	assert_true(probe.report().contains("試し: 伸びる板"), "伸びた板を拾わない: %s" % probe.report())
	made[0].free()
	probe.free()


## 大きさを決めた板は、文を替えても拾わない。置き場所だけが動いたものは、SIZE の印なら拾わず、RECT の印なら拾う。
func test_probe_passes_a_fixed_frame_and_tells_size_from_place() -> void:
	var probe := SteadyProbe.new()
	await settle(probe)
	var fixed := _marked("試し: 決まった板", Steady.SIZE)
	fixed[0].custom_minimum_size = Vector2(200.0, 40.0)
	fixed[1].clip_text = true
	var placed := _marked("試し: 置き場所も見る板", Steady.RECT)
	await settle(fixed[0])
	await settle(placed[0])
	await _frames(3)
	fixed[1].text = "長い文にしても、板は伸びない（中で切る）"
	fixed[0].position += Vector2(30.0, 0.0)
	await _frames(4)
	assert_eq(probe.report(), "", "決まった大きさの板を拾った")
	placed[0].position += Vector2(30.0, 0.0)
	await _frames(4)
	assert_true(probe.report().contains("試し: 置き場所も見る板"), "置き場所が動いた板を拾わない")
	fixed[0].free()
	placed[0].free()
	probe.free()


## 枠そのものを拡大する演出（マウスを乗せたカードが浮く）は、並びを動かさないので拾わない。入れ物ごと拡大したら、中の枠は拾う。
func test_probe_skips_a_frame_scaled_on_its_own() -> void:
	var probe := SteadyProbe.new()
	await settle(probe)
	var holder := Control.new()
	var card := _marked("試し: 浮くカード", Steady.RECT)
	card[0].custom_minimum_size = Vector2(200.0, 40.0)
	holder.add_child(card[0])
	await settle(holder)
	await _frames(3)
	card[0].pivot_offset = card[0].size / 2.0
	card[0].scale = Vector2.ONE * 1.05
	await _frames(4)
	assert_eq(probe.report(), "", "浮かせただけのカードを拾った")
	holder.scale = Vector2.ONE * 1.5
	await _frames(4)
	assert_true(probe.report().contains("試し: 浮くカード"), "入れ物ごと大きくなった枠を拾わない")
	holder.free()
	probe.free()


## 同じ名前の枠は、作り直しても同じ大きさ（並んだ札がそろう、選び直しで作り直す欄が動かない）。控えを捨てたら（場面が替わった）、比べ直す。
func test_probe_compares_frames_of_the_same_name() -> void:
	var probe := SteadyProbe.new()
	await settle(probe)
	var first := _marked("試し: 札", Steady.SIZE)
	await settle(first[0])
	await _frames(3)
	probe.forget_all()
	var second := _marked("試し: 札", Steady.SIZE)
	second[1].text = "名前の長い札"
	first[0].visible = false
	await settle(second[0])
	await _frames(4)
	assert_eq(probe.report(), "", "場面が替わったあとの枠を、前の場面の枠と比べた")
	first[0].visible = true
	await _frames(4)
	assert_true(probe.report().contains("試し: 札"), "同じ名前で大きさの違う札を拾わない")
	first[0].free()
	second[0].free()
	probe.free()


## 出撃準備と初期位置の窓の駒の欄: どの駒を出しても、何も出さなくても、同じ大きさ。名前は切れない。
func test_deploy_note_keeps_its_size_for_every_unit() -> void:
	UiTheme.install()  # 大きさは、ゲームと同じテーマ（字と余白）で測る
	var note := DeployNote.new()
	await settle(note)
	var size := Vector2(DeployNote.WIDTH, DeployNote.HEIGHT)
	assert_eq(note.size, size, "何も出していないとき")
	for kind: UnitKind.Id in UnitKind.Id.values():
		for level: int in [1, Growth.MAX_LEVEL]:
			for selected: bool in [false, true]:
				var unit := Unit.new(1, kind, Unit.Side.PLAYER1, Vector2i.ZERO)
				unit.level = level
				note.show_unit(unit, selected)
				await settle(note)
				assert_eq(note.size, size, "%s レベル %d" % [note.shown_name(), level])
				assert_false(note.is_name_cut(), "名前が切れる: %s レベル %d" % [note.shown_name(), level])
	note.show_unit(null)
	await settle(note)
	assert_eq(note.size, size, "駒を外したあと")
	note.free()


# ---- 対戦の HUD（game/battle_hud.gd）----


func _hud() -> BattleHud:
	UiTheme.install()
	var hud := BattleHud.new()
	hud.setup([Color.BLUE, Color.RED, Color.GRAY] as Array[Color])
	hud.battle = CpuGame.small_battle(1)
	return hud


## 印の付いた枠（名前 what）を、node の下から探す。
func _frame(node: Node, what: String) -> Control:
	for frame: Node in (Engine.get_main_loop() as SceneTree).get_nodes_in_group(Steady.GROUP):
		if Steady.name_of(frame as Control) == what and node.is_ancestor_of(frame):
			return frame as Control
	return null


## 情報の枠: どの駒を出しても（持ち物・状態・メニューの項目の説明を積んでも）、マスを出しても、同じ大きさ。下が切れず、札が枠の幅からはみ出さない。
func test_info_panel_keeps_its_size_whatever_it_shows() -> void:
	var hud := _hud()
	await settle(hud)
	var panel := _frame(hud, "battle.info")
	var size := Vector2(BattleHud.INFO_WIDTH + 20.0, BattleHud.INFO_HEIGHT)
	var items: Array[Equipment.Id] = [Equipment.Id.SPEED_BOOTS, Equipment.Id.REGEN_CHARM]
	for kind: UnitKind.Id in UnitKind.Id.values():
		# 素の駒と、中身を積んだ駒（持ち物 2 つ、状態 1 つ、HP が減っている）。積んだ駒は、メニューの項目に乗せた形（説明が足される）も。
		var plain := Unit.new(1, kind, Unit.Side.PLAYER1, Vector2i.ZERO)
		hud.show_unit(plain, BattleTexts.unit_state(hud.battle, plain), "")
		hud.set_detail_button(true)
		await settle(hud)
		assert_eq(panel.size, size, "素の駒: %s" % Names.kind(kind))
		assert_eq(hud.info_dropped(), 0, "素の駒で、欄が省かれる: %s" % Names.kind(kind))
		assert_true(hud.info_overflow() <= 0.5, "素の駒で、札が枠の幅からはみ出す（%.1f px）: %s" % [hud.info_overflow(), Names.kind(kind)])
		var loaded := Unit.new(2, kind, Unit.Side.PLAYER2, Vector2i.ZERO, items if Equipment.can_equip(kind) else ([] as Array[Equipment.Id]))
		loaded.statuses[Status.Type.values()[0]] = 2
		loaded.hp = maxi(loaded.max_hp() / 3, 1)
		for id: StringName in [BattleTexts.MENU_ATTACK, BattleTexts.MENU_SKILL, &""]:
			if id == BattleTexts.MENU_SKILL and Skills.of(loaded) == null:
				continue
			hud.show_unit(loaded, BattleTexts.unit_state(hud.battle, loaded) if id == &"" else "", BattleTexts.menu_note(id, loaded, hud.battle), id != BattleTexts.MENU_SKILL)
			hud.set_pin_switch(id == &"", false)
			hud.set_detail_button(true)
			await settle(hud)
			assert_eq(panel.size, size, "中身を積んだ駒: %s %s" % [Names.kind(kind), id])
			assert_false(hud.is_info_cut(), "中身を積んだ駒で、下が切れる: %s %s\n%s" % [Names.kind(kind), id, hud.info_text()])
			assert_true(hud.info_overflow() <= 0.5, "中身を積んだ駒で、札が枠の幅からはみ出す（%.1f px）: %s %s" % [hud.info_overflow(), Names.kind(kind), id])
			if id == &"":
				assert_eq(hud.info_dropped(), 0, "駒を見ているだけで、欄が省かれる: %s" % Names.kind(kind))
	# 札が込み合うと（状態 3 つ、いるマスの行、スイッチ）、後で読めるものから省いて、枠に収める。スキルの名前は残す。
	var crowded := Unit.new(3, UnitKind.Id.MEDIC, Unit.Side.PLAYER2, Vector2i.ZERO, items)
	for type: int in Status.Type.values().slice(0, 3):
		crowded.statuses[type] = 2
	hud.show_unit(crowded, "未行動\n" + Text.t("battle.unit.on_cell", {"terrain": Text.t("battle.cell.forest")}), "")
	hud.set_pin_switch(true, false)
	hud.set_detail_button(true)
	await settle(hud)
	assert_eq(panel.size, size, "込み合った駒")
	assert_true(hud.info_dropped() > 0 and not hud.is_info_cut(), "込み合った駒を、省いて収めていない（省いた数 %d）" % hud.info_dropped())
	assert_true(hud.info_text().contains(Names.skill(Skills.of(crowded))), "スキルの名前まで省いた")
	hud.show_cell_info("マス (12, 15)　平地", "拠点\n　将でない駒が乗ったまま番を終えると、確保 +1\n　6 で勝ち")
	await settle(hud)
	assert_eq(panel.size, size, "マス")
	assert_true(hud.info_overflow() <= 0.5, "マスの札が枠の幅からはみ出す")
	assert_eq(hud.info_title(), "マス (12, 15)　平地")
	assert_eq(hud.info_text(), "拠点\n将でない駒が乗ったまま番を終えると、確保 +1\n6 で勝ち", "マスの説明を、項目ごとの札に分けていない")
	hud.free()


## 情報の枠の札は、文の段落でなく欄で出す: 所属・役割・軍・レベルの札、能力値の行、状態の札（名前と残りのターン）、スキルの札、持ち物の枠。
func test_info_panel_is_a_status_card() -> void:
	var hud := _hud()
	await settle(hud)
	var items: Array[Equipment.Id] = [Equipment.Id.IRON_SHIELD, Equipment.Id.IRON_SHIELD]
	var trooper := Unit.new(1, UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i.ZERO, items)
	trooper.hp = 40
	trooper.statuses[Status.Type.values()[0]] = 2
	hud.show_unit(trooper, "未行動", "")
	await settle(hud)
	var lines := hud.info_text().split("\n")
	assert_eq(hud.info_title(), Names.kind(UnitKind.Id.SHIELD_TROOPER))
	assert_eq(lines[0], "自軍　%s　%s　Lv 1　未行動" % [Names.role(UnitKind.role(trooper.kind)), Names.army(UnitKind.army(trooper.kind))], "札の並び")
	assert_true(lines[1].begins_with("HP 40 / %d" % trooper.max_hp()), "HP の行: %s" % lines[1])
	assert_true(lines.has("%s（あと 2）" % Names.status(Status.Type.values()[0])), "状態の札: %s" % hud.info_text())
	assert_true(lines.has("持ち物: アイアンシールド ×2"), "持ち物の枠: %s" % hud.info_text())
	for line in lines:
		assert_false(line.contains("。") and line.length() > 60, "長い文の段落が残っている: %s" % line)
	hud.free()


## 下の帯: 案内（句と印の並び）とマスの説明を替えても、同じ大きさ。案内は使える幅に収まり、長いマスの説明は 2 行に折り返して、切れない。
func test_bottom_band_keeps_its_size_and_wraps_the_cell_line() -> void:
	var hud := _hud()
	await settle(hud)
	var band := _frame(hud, "battle.bottom_band")
	var size := band.size
	assert_eq(size.y, BattleHud.BOTTOM_BAR_HEIGHT)
	var long_guide: Array = [KeyMarks.phrase(Text.t("battle.guide.unacted", {"count": 12})), KeyMarks.swatch(Palette.TEXT, Text.t("battle.guide.move")),
		KeyMarks.swatch(Palette.TEXT, Text.t("battle.guide.cruise")), KeyMarks.swatch(Palette.TEXT, Text.t("battle.guide.attack")),
		KeyMarks.swatch(Palette.TEXT, Text.t("battle.guide.pinned"), true), KeyMarks.key(Text.t("common.key.right_click"), Text.t("battle.guide.cancel"))]
	var long_cell := Text.t("battle.cell.line", {"title": Text.t("battle.cell.title", {"x": 12, "y": 15, "terrain": Text.t("battle.cell.plain")}),
		"notes": Text.t("battle.cell.stronghold") + Text.paren(Text.t("battle.cell.stronghold.note", {"needed": 6, "radius": 2}))})
	for guide: Array in [[], long_guide]:
		for cell: String in ["", "マス (1, 2)　平地", long_cell]:
			hud.set_guide(guide)
			hud.show_cell(cell)
			await settle(hud)
			assert_eq(band.size, size, "案内「%s」、マス「%s」" % [hud.guide_text().left(6), cell.left(10)])
			assert_false(hud.guide_overflows(), "案内が、下の帯の欄からはみ出す: %s" % hud.guide_text())
	hud.show_cell(long_cell)
	assert_true(hud.cell_line_text().contains("\n"), "長いマスの説明が折り返されない")
	assert_eq(hud.cell_cut_lines(), [] as Array[String], "拠点の説明が、下の帯で切れる")
	hud.free()


## 駒のそばのメニュー: 項目の言葉を替えても、幅は同じ。どのスキルの項目も切れない。
func test_menu_keeps_its_width_and_fits_every_skill() -> void:
	var hud := _hud()
	await settle(hud)
	var texts: Array[String] = [Text.t("battle.menu.undo"), Text.t("battle.menu.skill.cooldown", {"turns": 3})]
	for kind: UnitKind.Id in UnitKind.Id.values():
		var unit := Unit.new(1, kind, Unit.Side.PLAYER1, Vector2i.ZERO)
		# メニューに実際に出る文字（スキルの名前。回数に上限のあるスキルは、残りの回数つき）。
		if Skills.of(unit) != null:
			texts.append(BattleTexts.skill_button_text(unit, true))
			texts.append(BattleTexts.skill_button_text(unit, false))
	hud.set_menu([[&"wait", Text.t("battle.menu.wait"), true]])
	await settle(hud)
	var width := hud.menu_size().x
	for text in texts:
		hud.set_menu([[&"skill", text, true], [&"wait", Text.t("battle.menu.wait"), true]])
		await settle(hud)
		assert_eq(hud.menu_size().x, width, "項目「%s」で、メニューの幅が変わる" % text)
		var button: Button = hud.menu_button(&"skill")
		var room := button.size.x - button.get_theme_stylebox("normal").get_minimum_size().x
		var needs := button.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
		assert_true(needs <= room + 0.5, "項目「%s」が切れる（要る幅 %d、入る幅 %d）" % [text, needs, room])
	hud.free()


# ---- 会話（game/talk_screen.gd、game/battle_talk.gd）----


## 会話の名前の札と、対戦の途中の台詞の名前の札は、決まった幅。全部の話の、どの話し手の名前も切れずに入る。
func test_name_plates_fit_every_speaker() -> void:
	var names := {}
	for episode in Story.all_episodes():
		for speaker: String in episode.speakers:
			names[speaker] = true
	assert_true(names.size() > 5, "話し手を読めていない")
	for speaker: String in names:
		var talk := UiTheme.FONT_BODY.get_string_size(speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 40.0
		assert_true(talk <= TalkScreen.PLATE_WIDTH, "会話の名前の札に入らない: %s（要る幅 %d）" % [speaker, talk])
		var cue := UiTheme.FONT_BOLD.get_string_size(speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 20.0
		assert_true(cue <= BattleTalk.PLATE_WIDTH, "途中の台詞の名前の札に入らない: %s（要る幅 %d）" % [speaker, cue])


## 決着の詳しい戦績の表の、名前の列の見出し: 対戦モードは「駒」、ストーリーは「名前」。
## 画面は対戦の始まる前（ストーリーかどうかが決まる前）に作られるので、表を出すときに決める。
func test_result_table_heading_follows_the_mode_at_show_time() -> void:
	var screen := ResultScreen.new()
	await settle(screen)
	var summary := ResultSummary.new()
	summary.tables = [{"name": "A", "summary": "", "rows": []}, {"name": "B", "summary": "", "rows": []}]
	screen.present(summary)
	screen.show_table(0)
	assert_eq(screen.table_unit_heading(), Text.t("result.table.unit"))
	Names.story_sides = true
	screen.show_table(1)
	assert_eq(screen.table_unit_heading(), Text.t("result.table.unit.story"), "ストーリーの表の見出しが「駒」のまま")
	Names.story_sides = false
	screen.free()


## 決着の画面の戦績の枠: 行の少ない戦績（中立撃破も聖遺物も無い）でも、行の多い戦績と同じ大きさ。
func test_result_stats_keep_their_size_whatever_the_lines() -> void:
	var screen := ResultScreen.new()
	await settle(screen)
	var sizes: Array[Vector2] = []
	for count: int in [2, ResultSummary.MAX_LINES, 3]:
		var summary := ResultSummary.new()
		summary.headline = "VICTORY"
		summary.focus_name = "MILITARY"
		for i in count:
			summary.lines.append(["項目 %d" % i, "%d 体" % (i * 7)])
		screen.present(summary)
		screen.skip()
		await settle(screen)
		sizes.append(screen._stats_panel.size)
		assert_eq(screen._stat_rows.size(), count, "埋めた空の行を、段階の出し方（音と間）に入れた")
	assert_eq(sizes[1], sizes[0], "戦績の行が増えると、枠が伸びた")
	assert_eq(sizes[2], sizes[0], "戦績の行が減ると、枠が縮んだ")
	screen.free()


## 軍略の札（印と名前。上の帯、部隊の一覧、「編成を確認」）は、どの軍略でも、軍略が無くても同じ大きさ。
func test_trait_tag_keeps_its_size_for_every_trait() -> void:
	var tag := TraitTag.new(22.0, 14)
	await settle(tag)
	var empty := tag.get_combined_minimum_size()
	for id: int in Traits.Id.values():
		tag.trait_id = id
		await settle(tag)
		assert_eq(tag.shown_name(), Names.troop_trait(id))
		assert_eq(tag.get_combined_minimum_size(), empty, "軍略の札の大きさが名前で変わる: %s" % Names.troop_trait(id))
		var name_width: float = UiTheme.FONT_BOLD.get_string_size(Names.troop_trait(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		assert_true(name_width <= TraitTag.name_width(14), "名前が欄に収まらない: %s" % Names.troop_trait(id))
	tag.free()



## 軍略の文（条件 → 効果の 1 文）は、出る所の欄（部隊編成の欄・編成確認・対戦中の窓）に、どの軍略でも収まり、欄の大きさは変わらない。
## 効果（数のある所）は、文の中にそのまま入っている（色を変える所が見つかる）。
func test_trait_sentence_fits_every_place_for_every_trait() -> void:
	var places := [
		TraitSentence.new(DeckBase.ROSTER_WIDTH - 24.0, DeckBase.TRAIT_TEXT_FONT, 2),
		TraitSentence.new(DeckPreview.TRAIT_TEXT_WIDTH, 15, 1),
		TraitSentence.new(TraitCard.TEXT_WIDTH, TraitCard.TEXT_FONT, TraitCard.TEXT_MAX_LINES),
	]
	for sentence: Control in places:
		await settle(sentence)
		var empty: Vector2 = sentence.get_combined_minimum_size()
		for id: int in Traits.Id.values():
			sentence.trait_id = id
			await settle(sentence)
			assert_true(Names.troop_trait_text(id).contains(Names.troop_trait_effect(id)), "文に効果が入っていない: %s" % Names.troop_trait_text(id))
			assert_false(sentence.overflows(), "軍略の文が欄に収まらない（%d 行）: %s" % [sentence.line_count(), sentence.shown_text()])
			assert_eq(sentence.get_combined_minimum_size(), empty, "軍略の文の欄の大きさが中身で変わる")
		sentence.free()

## 出撃準備の枠（初期位置・勝利条件・敵の部隊・出撃する部隊）は、どの話でも同じ場所・同じ大きさ。
## 演習（覚えることの札が出る、部隊が決まっている）、ふつうの話、勝利条件の札が 3 枚で敵の多い話、敵のいちばん多い話で比べる。
func test_sortie_frames_are_the_same_for_every_episode() -> void:
	var first := {}
	var first_id := ""
	for id: StringName in [&"ridge_path", &"drill_sniper", &"ridge_hold", &"ridge_bones"]:
		var episode: RefCounted = null
		for found: RefCounted in Story.all_episodes():
			if found.id == id:
				episode = found
		assert_true(episode != null, "話が無い: %s" % id)
		if episode == null:
			continue
		var context := preload("res://game/app_context.gd").new()
		context.run = context.story.run_now(episode)
		context.scene = Story.SORTIE
		var sortie := SortieScreen.new()
		sortie.context = context
		await settle(sortie)
		await _frames(1)
		var rects: Dictionary = sortie.frame_rects()
		assert_eq(rects.size(), 6, "%s: 枠が足りない: %s" % [id, rects.keys()])
		for frame: Control in sortie.get_tree().get_nodes_in_group(Steady.GROUP):
			if sortie.is_ancestor_of(frame):
				assert_eq(SteadyProbe.spill_of(frame), "", "%s: %s の中身が枠からはみ出す" % [id, Steady.name_of(frame)])
		assert_true(sortie.options_scroll().size.y >= (SortieScreen.OPTION_HEIGHT + SortieScreen.OPTION_GAP) * SortieScreen.OPTIONS_SHOWN - SortieScreen.OPTION_GAP,
				"%s: 選べる部隊の並びに、%d 行ぶんの高さが無い" % [id, SortieScreen.OPTIONS_SHOWN])
		assert_true(sortie.needed_height() <= 720.0, "%s: 720 の高さに収まらない（%s）" % [id, sortie.needed_height()])
		assert_eq(sortie.lesson_text(), episode.lesson, "%s: 覚えることの札の文" % id)
		if first.is_empty():
			first = rects
			first_id = id
		else:
			for what: String in rects:
				assert_eq(rects[what], first.get(what), "%s の枠が、話で違う（%s と %s）" % [what, first_id, id])
		sortie.free()


## 出撃準備の選べる部隊の並び: 取っておいた部隊が多くても、3 部隊ぶんが丸ごと見え、ホイールの 1 目盛りで 1 行送る。
## 選んだ部隊の中身の文は、長い部隊でも決まった行の数に収まる（欄の割り振りは部隊で変わらない）。
func test_sortie_shows_three_squads_and_scrolls_by_a_row() -> void:
	var episode: RefCounted = Story.military().find_episode(&"ridge_hold")
	var context := preload("res://game/app_context.gd").new()
	context.story.open_all = true
	context.decks.load_data({"decks": []})
	var long_deck := Deck.new(Story.military().army, context.story.deck_rules())
	for kind: UnitKind.Id in context.story.unlocked().kinds:
		for n in 3:
			if long_deck.total_cost() + UnitKind.cost(kind) <= long_deck.budget():
				long_deck.add(kind)
	var saved: Array = []
	for i in 6:
		saved.append(context.decks.add("部隊 %d" % (i + 1), long_deck))
	# いちばん小さい字でも 2 行に収まらない部隊（盾持ち 6 体に、みなアイアンシールド）: 切って、全部はマウスを乗せると出る。
	var heavy := Deck.new(Story.military().army, context.story.deck_rules())
	for n in 6:
		heavy.add(UnitKind.Id.SHIELD_TROOPER).equipment.append(Equipment.Id.IRON_SHIELD)
	assert_true(heavy.is_valid(), "見本の部隊が出撃できない: %s" % [heavy.problems()])
	var heavy_saved: RefCounted = context.decks.add("重い部隊", heavy)
	context.run = context.story.run_now(episode)
	context.scene = Story.SORTIE
	var sortie := SortieScreen.new()
	sortie.context = context
	await settle(sortie)
	await _frames(1)
	assert_eq(sortie.option_ids().size(), 8)
	assert_true(sortie.is_option_enabled(heavy_saved.id))
	assert_true(sortie.options_fully_shown() >= SortieScreen.OPTIONS_SHOWN, "丸ごと見える部隊が %d つ" % sortie.options_fully_shown())
	var rects: Dictionary = sortie.frame_rects()
	for id: String in sortie.option_ids():
		sortie.choose(id)
		await settle(sortie)
		assert_true(sortie.deck_line_text().count("\n") < SortieScreen.DECK_LINES, "部隊の中身の文が %d 行に収まらない: %s" % [SortieScreen.DECK_LINES, sortie.deck_line_text()])
		assert_eq(sortie.frame_rects(), rects, "部隊を選び替えると、枠が動く")
		assert_true(sortie.needed_height() <= 720.0, "部隊を選ぶと、720 の高さに収まらない")
	sortie.choose(heavy_saved.id)
	assert_true(sortie.deck_line_text().ends_with("…"), "収まらない部隊の文は、切って「…」")
	assert_eq(sortie.deck_line_text().count("\n"), SortieScreen.DECK_LINES - 1, "切った文は、決まった行の数")
	assert_eq(sortie.deck_line_tooltip().count(Names.item(Equipment.Id.IRON_SHIELD)), 6, "切れた文の全部は、マウスを乗せると出る")
	assert_eq(sortie.frame_rects(), rects, "収まらない部隊を選んでも、枠は動かない")
	sortie.choose(SortieScreen.DEFAULT_ID)
	assert_eq(sortie.deck_line_tooltip(), "", "収まる部隊では、乗せても何も出さない")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	sortie.options_scroll().gui_input.emit(wheel)
	await _frames(1)
	assert_eq(sortie.options_scroll().scroll_vertical, int(SortieScreen.OPTION_HEIGHT + SortieScreen.OPTION_GAP), "ホイールの 1 目盛りで 1 行")
	sortie.free()


## 見張りは、印の付いた枠の中身が枠からはみ出したことも拾う（枠は伸びないのに、中の並びのほうが大きい）。
func test_probe_catches_contents_that_stick_out_of_a_frame() -> void:
	var probe := SteadyProbe.new()
	await settle(probe)
	var card := Button.new()
	card.custom_minimum_size = Vector2(200.0, 80.0)
	Steady.mark(card, "試し: 中身の大きいカード")
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(row)
	var part := ColorRect.new()
	part.custom_minimum_size = Vector2(120.0, 40.0)
	row.add_child(part)
	await settle(card)
	await _frames(SteadyProbe.SPILL_EVERY * 3)
	assert_eq(probe.report(), "", "収まっているのに拾った")
	part.custom_minimum_size.x = 260.0
	await _frames(SteadyProbe.SPILL_EVERY * 3)
	assert_true(probe.report().contains("試し: 中身の大きいカード"), "はみ出しを拾わない: %s" % probe.report())
	probe.spilled.clear()
	Steady.let_out(row)
	await _frames(SteadyProbe.SPILL_EVERY * 3)
	assert_eq(probe.report(), "", "わざと外へ出した部品（let_out）を拾った")
	card.free()
	probe.free()


## 物語のカード: 顔の並びは、駒の数がいくつでも決まった幅の欄に収まり、カードの中身はカードからはみ出さない。
func test_campaign_cards_hold_any_number_of_faces() -> void:
	var CampaignList: GDScript = load("res://game/campaign_list_screen.gd")
	var screen: Node = CampaignList.new()
	await settle(screen)
	await _frames(1)
	for campaign: RefCounted in Story.campaigns():
		assert_eq(SteadyProbe.spill_of(screen.card_of(campaign)), "", "%s のカードの中身がはみ出す" % campaign.title)
	screen.free()
	var crowded: RefCounted = Story.military().get_script().new()
	crowded.army = UnitKind.Army.MILITARY
	for count in range(0, 10):
		var row: HBoxContainer = CampaignList.faces_row(crowded)
		await settle(row)
		assert_true(row.get_minimum_size().x <= CampaignList.FACES_WIDTH + 0.5, "顔 %d つの並びが欄より広い: %s" % [count + 1, row.get_minimum_size().x])
		assert_eq(CampaignList.faces_shown(row), mini(count + 1, CampaignList.FACES_MAX))
		row.free()
		crowded.starting_kinds.append(UnitKind.Id.SNIPER)
