extends "res://tests/base_test.gd"
## 枠の大きさは中身で変えない（docs/ui-theme.md の「枠の大きさ」）。
## - 枠の見張り（game/steady_probe.gd）が、印の付いた枠（game/steady.gd）の伸び縮みを拾うこと。
## - 中身を次々替えても大きさが変わらない部品を、1 つずつ。自動の対戦では通りにくい中身（全部の駒、いちばん長い文）を当てる。

const Steady := preload("res://game/steady.gd")
const SteadyProbe := preload("res://game/steady_probe.gd")
const DeployNote := preload("res://game/deploy_note.gd")
const UiTheme := preload("res://game/ui_theme.gd")


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
