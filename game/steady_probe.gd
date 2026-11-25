extends Node
## 枠の大きさが、出ている間に変わらないことを見張る（docs/ui-theme.md の「枠の大きさ」）。
## 検査（自動の対戦・通しの点検・スクリーンショットの道具）のときだけ、アプリの入口が 1 つ持つ。遊ぶときは作らない。
##
## 毎コマ、印の付いた枠（steady.gd）の四角を控え、同じ枠が前と違う大きさ（RECT の印なら置き場所も）で出たら、moved に積む。
## 同じ名前の枠は、作り直されても同じ大きさで出ること（並んだ札もそろう）。
## 窓の大きさが変わったときと、場面（scene_flow.gd）が替わったときは、控えを捨てる（画面が変われば枠も変わってよい）。
## 枠の中の文も見る: 印の付いた枠の中の Label が、入っている箱（ボタン、板）からはみ出していないか、
## 字を切る Label（clip_text）が字を切っていないか。cut_texts に積む（枠の中に収まっていても、ボタンからあふれた文を拾う）。
## `-- --frames` を付けると、洗い出し: 印の無い板（PanelContainer、Panel、ScrollContainer）も全部控え、終わりに動いたものを並べる。

const Steady := preload("res://game/steady.gd")

## これより小さい差は、同じとみなす（端数の丸め）。
const SLACK := 0.75
## 中身のはみ出しは、これより大きいものを数える（px。縁取りや丸めの分）。何コマに 1 度見るか。
const SPILL_SLACK := 1.0
const SPILL_EVERY := 6

## 印の付いた枠のうち、動いたもの。名前 -> 「前の四角 → あとの四角」。
var moved := {}
## 印の付いた枠のうち、中身が枠の外へはみ出したもの。名前 -> 「はみ出した部品 はみ出した向きと px」。
var spilled := {}
## 印の付いた枠の中で、文が箱からはみ出した・切れたもの。「枠の名前「文」」 -> どうなったか。
var cut_texts := {}
## 前に見たときにあふれていた文（並べ直しの途中の 1 回は数えない。続けて 2 回なら cut_texts に積む）。キー -> 見た回。
var _cut_before := {}
var _cut_round := 0
## 洗い出しで、印の無い板のうち大きさが変わったもの。名前 -> 見た大きさの列。
var found := {}

var _everything := false
## 印の付いた枠は名前、印の無い板は instance id -> [控えた四角, （使わない）, 名前]
var _seen := {}
## 枠（instance id）-> [前のコマに見た、控えと違う四角, そのコマ]
var _odd := {}
var _hooked := {}
## 枠の名前 -> 前に見たときのはみ出し（無ければ ""）
var _spill_before := {}
var _screen := Vector2.ZERO


func _init(everything := false) -> void:
	_everything = everything
	process_priority = 1000


func _process(_delta: float) -> void:
	var screen := get_viewport().get_visible_rect().size
	if screen != _screen:
		_screen = screen
		forget_all()
		return
	var spill_check := Engine.get_process_frames() % SPILL_EVERY == 0
	if spill_check:
		_cut_round += 1
	for frame: Node in get_tree().get_nodes_in_group(Steady.GROUP):
		_sample(frame as Control, true)
		if spill_check:
			_check_spill(frame as Control)
			if (frame as Control).is_visible_in_tree():
				_check_texts(frame as Control, frame, [frame as Control])
	if _everything:
		_walk(get_tree().root)


## 控えを捨てる（窓の大きさが変わった、場面が替わった）。動いたものの記録は残す。
func forget_all() -> void:
	_seen.clear()
	_odd.clear()
	_spill_before.clear()
	_cut_before.clear()


## 印の付いた枠 frame の中身（見えている部品）が、枠の四角からはみ出していたら spilled に積む。
## 枠が中身より小さいのに伸びない作り（ボタンのカードの中に、四隅を留めた並びを置く、など）は、枠の大きさが変わらないので、
## 大きさの見張りには掛からない。ここで拾う。
## 見ないもの: 枠の中で送る欄（ScrollContainer）と切り抜く部品（clip_contents）の中、大きさの無い部品、
## わざと枠の外へ出す部品（Steady.let_out）、拡大・回転している途中の部品。
func _check_spill(frame: Control) -> void:
	if frame == null or not frame.is_visible_in_tree() or frame.clip_contents or frame is ScrollContainer:
		return
	var name := Steady.name_of(frame)
	if spilled.has(name) or frame.size.x <= 0.0 or frame.size.y <= 0.0:
		return
	var inverse := frame.get_global_transform().affine_inverse()
	var out := _spill_in(frame, Rect2(Vector2.ZERO, frame.size).grow(SPILL_SLACK), inverse)
	# 並べ直しの途中（行を作り直した直後など）は数えない。続けて 2 度、同じはみ出しを見たら積む。
	if out != "" and _spill_before.get(name, "") == out:
		spilled[name] = out
	_spill_before[name] = out


## 枠 frame の中身のはみ出し（「部品 が N px」。無ければ ""）。テスト用にも（木に入れて 1 コマ待ってから）。
static func spill_of(frame: Control) -> String:
	var probe: Node = (load("res://game/steady_probe.gd") as GDScript).new()
	var out: String = probe._spill_in(frame, Rect2(Vector2.ZERO, frame.size).grow(SPILL_SLACK), frame.get_global_transform().affine_inverse())
	probe.free()
	return out


func _spill_in(node: Node, bounds: Rect2, inverse: Transform2D) -> String:
	for child in node.get_children():
		var control := child as Control
		if control == null:
			continue  # 3D の枠・重なる窓など。中は別の座標なので見ない
		if not control.visible or control.top_level or Steady.is_let_out(control):
			continue
		var local := inverse * control.get_global_transform()
		if not local.get_scale().is_equal_approx(Vector2.ONE) or not is_zero_approx(local.get_rotation()):
			continue  # 浮く演出の途中
		var rect := Rect2(local.origin, control.size)
		if rect.size.x > 0.0 and rect.size.y > 0.0 and not bounds.encloses(rect):
			var over := maxf(maxf(bounds.position.x - rect.position.x, rect.end.x - bounds.end.x), maxf(bounds.position.y - rect.position.y, rect.end.y - bounds.end.y))
			return "%s が %d px" % [_describe(control) if is_inside_tree() else control.get_class(), ceili(over - SPILL_SLACK)]
		if control.clip_contents or control is ScrollContainer:
			continue
		var inner := _spill_in(control, bounds, inverse)
		if inner != "":
			return inner
	return ""


## 枠 frame の中の Label を見る。boxes は、いま見ている Label を入れている箱（枠、ボタン、板）の並び。
## 中身が動く入れ物（ScrollContainer）の中は見ない（見える所の外に出るのが当たり前なので）。
func _check_texts(frame: Control, node: Node, boxes: Array) -> void:
	for child in node.get_children():
		if not child is Control or not (child as Control).visible or child is ScrollContainer or Steady.is_let_out(child as Control):
			continue
		var control := child as Control
		if control is Label:
			_check_label(frame, control as Label, boxes)
		var inner := boxes
		if control is Button or control is PanelContainer or control is Panel:
			inner = boxes + [control]
		_check_texts(frame, control, inner)


func _check_label(frame: Control, label: Label, boxes: Array) -> void:
	if label.text == "" or label.get_global_transform().get_scale() != Vector2.ONE:
		return
	var rect := label.get_global_rect()
	var problem := ""
	for box: Control in boxes:
		if box.get_global_transform().get_scale() != Vector2.ONE:
			return  # 拡大の演出の途中（マウスを乗せたカード）は見ない
		if not box.get_global_rect().grow(SLACK).encloses(rect):
			var what := "枠" if box == frame else ("ボタン" if box is Button else "板")
			problem = "%sの外へはみ出した: 文 %s、%s %s" % [what, _text(rect), what, _text(box.get_global_rect())]
			break
	if problem == "" and label.clip_text and label.autowrap_mode == TextServer.AUTOWRAP_OFF \
			and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
		var font := label.get_theme_font(&"font")
		var font_size := label.get_theme_font_size(&"font_size")
		var shown_lines := label.text.split("\n")
		if label.max_lines_visible > 0:
			shown_lines = shown_lines.slice(0, label.max_lines_visible)
		for line: String in shown_lines:
			if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > label.size.x + SLACK:
				problem = "字が切れた"
				break
	if problem == "":
		return
	var key := "%s「%s」" % [Steady.name_of(frame), label.text.replace("\n", " ").left(16)]
	if _cut_before.get(key, -10) != _cut_round - 1:
		_cut_before[key] = _cut_round
		return
	if not cut_texts.has(key):
		cut_texts[key] = problem


func _walk(node: Node) -> void:
	for child in node.get_children():
		if child is Control and not (child as Control).visible:
			continue
		if (child is PanelContainer or child is Panel or child is ScrollContainer) and not child.is_in_group(Steady.GROUP):
			_sample(child as Control, false)
		_walk(child)


func _sample(frame: Control, marked: bool) -> void:
	if frame == null or not frame.is_visible_in_tree():
		return
	# 印の付いた枠は、名前で控える（作り直されても、同じ名前の枠は同じ大きさ。並んだ札もそろう）。印の無い板は、その板ごと。
	var key: Variant = Steady.name_of(frame) if marked else frame.get_instance_id()
	var kind: StringName = Steady.kind_of(frame) if marked else Steady.SIZE
	var with_place := kind == Steady.RECT
	var rect := _rect_of(frame)
	if kind == Steady.WIDTH:
		rect.size.y = 0.0  # 高さは見ない
	if not _seen.has(key):
		_seen[key] = [rect, rect, key if marked else _describe(frame)]
		if not marked and not _hooked.has(key):
			_hooked[key] = true
			frame.tree_exiting.connect(_forget.bind(key), CONNECT_ONE_SHOT)
		return
	var entry: Array = _seen[key]
	if _same(entry[0], rect, with_place):
		return
	# 並べ直しの途中の 1 コマは数えない。同じ枠が 2 コマ続けて同じ違う四角だったら、動いたとする。
	var id := frame.get_instance_id()
	var frame_now := Engine.get_process_frames()
	var odd: Array = _odd.get(id, [])
	if odd.is_empty() or odd[1] != frame_now - 1 or not _same(odd[0], rect, true):
		_odd[id] = [rect, frame_now]
		return
	_odd.erase(id)
	if marked:
		if not moved.has(entry[2]):
			moved[entry[2]] = "%s → %s" % [_text(entry[0]), _text(rect)]
	else:
		var sizes: Array = found.get_or_add(entry[2], [_size_text(entry[0])])
		if not sizes.has(_size_text(rect)) and sizes.size() < 6:
			sizes.append(_size_text(rect))
		entry[0] = rect


## 枠の四角（画面の上の置き場所と大きさ）。枠そのものの拡大（マウスを乗せたカードが浮く演出。scale）は、並びを動かさないので数えない。
## 入れ物ごと拡大したときは、中の枠も大きく見えるので数える。
static func _rect_of(frame: Control) -> Rect2:
	var outer := frame.get_global_transform() * frame.get_transform().affine_inverse()
	return Rect2(outer * frame.position, frame.size * outer.get_scale())


func _forget(id: int) -> void:
	_seen.erase(id)
	_odd.erase(id)
	_hooked.erase(id)


static func _same(a: Rect2, b: Rect2, with_place: bool) -> bool:
	if absf(a.size.x - b.size.x) > SLACK or absf(a.size.y - b.size.y) > SLACK:
		return false
	return not with_place or (absf(a.position.x - b.position.x) <= SLACK and absf(a.position.y - b.position.y) <= SLACK)


static func _text(rect: Rect2) -> String:
	return "(%d, %d) %s" % [roundi(rect.position.x), roundi(rect.position.y), _size_text(rect)]


static func _size_text(rect: Rect2) -> String:
	return "%d×%d" % [roundi(rect.size.x), roundi(rect.size.y)]


## 印の無い板の名前: 持ち主のスクリプトをたどった道と、中の最初の文。
func _describe(frame: Control) -> String:
	var trail: Array[String] = []
	var node: Node = frame
	while node != null and node != get_tree().root:
		var script: Script = node.get_script()
		if script != null:
			trail.push_front(script.resource_path.get_file().get_basename())
		elif node == frame or not node.name.begins_with("@"):
			trail.push_front(String(node.name) if not node.name.begins_with("@") else node.get_class())
		node = node.get_parent()
	return "%s「%s」" % ["/".join(trail), _first_text(frame).left(14)]


func _first_text(node: Node) -> String:
	for child in node.get_children():
		if child is Label and (child as Label).text != "":
			return (child as Label).text.replace("\n", " ")
		if child is Button and (child as Button).text != "":
			return (child as Button).text
		var inner := _first_text(child)
		if inner != "":
			return inner
	return ""


## 動いた枠の報告（無ければ空）。
func report() -> String:
	var lines: Array[String] = []
	for what: String in moved:
		lines.append("枠が動いた: %s（%s）" % [what, moved[what]])
	for what: String in spilled:
		lines.append("枠から中身がはみ出した: %s（%s）" % [what, spilled[what]])
	for what: String in cut_texts:
		lines.append("文があふれた: %s（%s）" % [what, cut_texts[what]])
	return "\n  ".join(lines)


func found_report() -> String:
	var lines: Array[String] = []
	for what: String in found:
		lines.append("%s: %s" % [what, " / ".join(found[what])])
	lines.sort()
	return "\n".join(lines)

