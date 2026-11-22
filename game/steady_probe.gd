extends Node
## 枠の大きさが、出ている間に変わらないことを見張る（docs/ui-theme.md の「枠の大きさ」）。
## 検査（自動の対戦・通しの点検・スクリーンショットの道具）のときだけ、アプリの入口が 1 つ持つ。遊ぶときは作らない。
##
## 毎コマ、印の付いた枠（steady.gd）の四角を控え、同じ枠が前と違う大きさ（RECT の印なら置き場所も）で出たら、moved に積む。
## 同じ名前の枠は、作り直されても同じ大きさで出ること（並んだ札もそろう）。
## 窓の大きさが変わったときと、場面（scene_flow.gd）が替わったときは、控えを捨てる（画面が変われば枠も変わってよい）。
## `-- --frames` を付けると、洗い出し: 印の無い板（PanelContainer、Panel、ScrollContainer）も全部控え、終わりに動いたものを並べる。

const Steady := preload("res://game/steady.gd")

## これより小さい差は、同じとみなす（端数の丸め）。
const SLACK := 0.75

## 印の付いた枠のうち、動いたもの。名前 -> 「前の四角 → あとの四角」。
var moved := {}
## 洗い出しで、印の無い板のうち大きさが変わったもの。名前 -> 見た大きさの列。
var found := {}

var _everything := false
## 印の付いた枠は名前、印の無い板は instance id -> [控えた四角, （使わない）, 名前]
var _seen := {}
## 枠（instance id）-> [前のコマに見た、控えと違う四角, そのコマ]
var _odd := {}
var _hooked := {}
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
	for frame: Node in get_tree().get_nodes_in_group(Steady.GROUP):
		_sample(frame as Control, true)
	if _everything:
		_walk(get_tree().root)


## 控えを捨てる（窓の大きさが変わった、場面が替わった）。動いたものの記録は残す。
func forget_all() -> void:
	_seen.clear()
	_odd.clear()


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
	var rect := frame.get_global_rect()
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
	return "\n  ".join(lines)


func found_report() -> String:
	var lines: Array[String] = []
	for what: String in found:
		lines.append("%s: %s" % [what, " / ".join(found[what])])
	lines.sort()
	return "\n".join(lines)

