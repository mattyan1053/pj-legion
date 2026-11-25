extends PanelContainer
## 初期位置の縮図（deploy_map.gd）の横の、駒の欄。縮図だけでは、アイコンを見て誰を動かすのかを当てないといけないので、
## 選んでいる駒（選んでいなければ、マウスを乗せている駒）の額・名前・役割・能力値を出す。どちらも無ければ、そう書くだけ。
## 出撃準備（sortie_screen.gd）と、対戦設定の初期位置の窓（deploy_dialog.gd）が、縮図の下に置く（横長。高さは中身で変わらない）。

const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")
const DeckText := preload("res://game/deck_text.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")
const UnitFrame := preload("res://game/unit_frame.gd")
const StatsRow := preload("res://game/stats_row.gd")
const DeployMap := preload("res://game/deploy_map.gd")

## 欄の幅と高さ（px）。駒を替えても、何も出していなくても、この大きさ（docs/ui-theme.md の「枠の大きさ」）。
## 幅は、いちばん長い中身（名前・役割とレベルの札・「マウスを乗せた駒」）が切れずに入る幅。縮図がこれより狭いマップでは、板のほうがこの幅になる。
## それでも入らない名前は「…」で切る（枠は広げない）。tests/game/test_steady_frames.gd が、どの駒も切れないことを確かめる。
const WIDTH := 460.0
const HEIGHT := 68.0
## 能力値の 1 項目の幅（px）。
const STAT_WIDTH := 52.0

var _map: DeployMap
var _frame: UnitFrame
var _name: Label
var _role: Label
var _role_tag: PanelContainer
var _state: Label
var _stats: StatsRow
var _hint: Label
var _shown_id := -1


func _init() -> void:
	theme_type_variation = UiTheme.PANEL_CARD
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	_frame = UnitFrame.new(UnitKind.Id.KING, 0, 48.0)
	_frame.chosen = true
	row.add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	var names := HBoxContainer.new()
	names.add_theme_constant_override("separation", 8)
	column.add_child(names)
	_name = _label(17, Palette.TEXT)
	_name.name = "Name"
	# 名前は残りの幅を取り、入らなければ「…」で切る（欄を広げない）。
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(_name)
	# 役割は小さな札（ステータスの窓と同じ形。PANEL_TAG）。
	_role_tag = PanelContainer.new()
	_role_tag.theme_type_variation = UiTheme.PANEL_TAG
	_role_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_role_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(_role_tag)
	_role = _label(12, Palette.TEXT)
	_role.name = "Role"
	_role_tag.add_child(_role)
	_state = _label(13, Palette.ACCENT)
	_state.name = "State"
	_state.size_flags_vertical = Control.SIZE_SHRINK_END
	names.add_child(_state)
	_stats = StatsRow.new("", 13, STAT_WIDTH)
	column.add_child(_stats)
	_hint = _label(14, Palette.TEXT_DIM)
	_hint.name = "Hint"
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_hint)
	show_unit(null)  # 縮図を見る前も、何も出していないときの形（同じ大きさ）


## 見る縮図を決める。縮図の選び直し・マウスの出入りに合わせて、欄を描き直す。
func watch(map: DeployMap) -> void:
	_map = map
	map.focus_changed.connect(refresh)
	map.changed.connect(refresh)
	refresh()


## 欄を、いまの縮図に合わせて描き直す。
func refresh() -> void:
	show_unit(_map.focused_unit() if _map != null else null, _map != null and _map.selected() != -1)


## 欄に駒 unit を出す（null なら、何も出していないと書く）。selected は、選んでいる駒か（そうでなければ、マウスを乗せた駒）。
func show_unit(unit: Unit, selected := false) -> void:
	var has_unit := unit != null
	_frame.visible = has_unit
	_name.visible = has_unit
	_role_tag.visible = has_unit
	_stats.visible = has_unit
	# 選んでいる駒にだけ「選択中」。マウスを乗せただけの駒は、額の縁（金でない）で見分ける。
	_state.visible = has_unit and selected
	_hint.visible = not has_unit
	if not has_unit:
		_shown_id = -1
		# 使い方の案内は書かない（docs/story.md の「出撃準備」）。何も出していないことだけ。
		_hint.text = Text.t("deploy.note.none")
		return
	_shown_id = unit.id
	_frame.set_kind(unit.kind, unit.side, unit.evolution != Evolution.Id.NONE)
	if _map != null:
		_frame.edge = Color(_map.team_color(), 0.85)
	_frame.chosen = selected
	_name.text = Names.kind(unit.kind)
	var role := DeckText.role_name(unit.kind)
	_role.text = Text.t("deploy.note.role_level", {"role": role, "level": unit.level}) if unit.level > 1 else role
	_role_tag.visible = _role.text != ""
	_stats.set_line(Text.t("deck.stats_healer" if UnitKind.role(unit.kind) == UnitKind.Role.HEALER else "deck.stats", {
		"hp": unit.max_hp(), "power": unit.power(), "move": unit.move_range(), "range": unit.attack_range(),
		"strike": Combat.attack_power(unit),
	}))
	_state.text = Text.t("deploy.note.selected")


## 出している駒の番号（無ければ -1。検査用）。
func shown_unit_id() -> int:
	return _shown_id


## 名前が「…」で切れているか（検査用。木に入れて 1 コマ待ってから）。
func is_name_cut() -> bool:
	var font := _name.get_theme_font("font")
	return _name.visible and font.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _name.get_theme_font_size("font_size")).x > _name.size.x + 0.5


## 出している名前（検査用）。
func shown_name() -> String:
	return _name.text if _name.visible else ""


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
