extends Node3D
## 部隊の特徴が効く兵の、頭の上の札（docs/troop-traits.md の「対戦の画面」）。増える数（「+2」）を、特徴の軍の色で出す。
## 足元の輪だけだと、拠点の竿・盾・選択の輪に埋もれる。札は頭の上で、いつもカメラを向き、駒や木に隠れず、画面の上で同じ大きさ。
## 形で役を分ける: 狙うと増える敵（集中砲火・仇討ち・誓い）は照準の印、攻撃が増える味方（単騎）は上向きの印。
## 色と形は、ほかの盤の表示（拠点の白い数、HP の棒、状態の水色の輪、選択の黄色い輪、範囲の塗り）と重ならない: 暗い地の札 + 軍の色の縁。

const Palette := preload("res://game/ui_palette.gd")

## 札の役（印の形）。
enum Kind { TARGET, ATTACKER }

## 札の絵の大きさ（px。2 倍で描いて半分で出す）と、下の尖りの高さ、印の欄の幅。
const PLATE := Vector2i(92, 46)
const TIP := 12
const ICON_WIDTH := 38
## 1 px の大きさ（fixed_size。画面の高さ 720 で、絵の 2 px がほぼ 1 px）。
const PIXEL := 0.00045
const FONT_SIZE := 34
## 札の地に混ぜる軍の色の割合（暗い地に軍の色を差す。連邦は茶、騎士領は紫に見える）。
const PLATE_TINT := 0.38

static var _textures: Dictionary = {}

var _plate: Sprite3D
var _label: Label3D
## いま出している文と役（検査用）。
var text := ""
var kind := Kind.TARGET


func _init() -> void:
	_plate = Sprite3D.new()
	_plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_plate.no_depth_test = true
	_plate.fixed_size = true
	_plate.shaded = false
	_plate.pixel_size = PIXEL
	_plate.render_priority = 3
	_plate.offset = Vector2(0.0, (PLATE.y + TIP) / 2.0)  # 尖りの先が、駒の頭の上の点に来る
	add_child(_plate)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = PIXEL
	_label.font_size = FONT_SIZE
	_label.outline_size = 0
	_label.render_priority = 4
	_label.offset = Vector2(ICON_WIDTH / 2.0 - 3.0, TIP + PLATE.y / 2.0)
	add_child(_label)


## 札の中身を替える。shown は増える数の文（「+2」）、color は特徴の軍の色。
func show_mark(shown: String, color: Color, mark_kind: Kind) -> void:
	text = shown
	kind = mark_kind
	_label.text = shown
	_label.modulate = color.lightened(0.55)
	_plate.texture = _texture(color, mark_kind)


static func _texture(color: Color, mark_kind: Kind) -> Texture2D:
	var key := "%s/%d" % [color.to_html(), mark_kind]
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(_draw(color, mark_kind))
	return _textures[key]


## 札の絵: 角の丸い暗い地、軍の色の縁、下の尖り、左に役の印。
static func _draw(color: Color, mark_kind: Kind) -> Image:
	var image := Image.create_empty(PLATE.x, PLATE.y + TIP, false, Image.FORMAT_RGBA8)
	var edge := color.lightened(0.1)
	var bright := color.lightened(0.55)
	var fill := Color(Palette.INK.lerp(color, PLATE_TINT), 0.95)
	var half := Vector2(PLATE) / 2.0
	var icon := Vector2(ICON_WIDTH / 2.0 + 4.0, half.y)
	for y in PLATE.y + TIP:
		for x in PLATE.x:
			var p := Vector2(x + 0.5, y + 0.5)
			# 札（角の丸い四角）と尖り（下向きの三角）までの距離。負なら中。
			var q := (p - half).abs() - (half - Vector2(9.0, 9.0))
			var plate := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - 9.0
			var tip := maxf(absf(p.x - half.x) - (PLATE.y + TIP - p.y), PLATE.y - 3.0 - p.y)
			var d := minf(plate, tip)
			if d > 0.0:
				continue
			var pixel := edge if d > -3.0 else fill
			if d <= -3.0 and _in_icon(p - icon, mark_kind):
				pixel = bright
			image.set_pixel(x, y, pixel)
	return image


## 役の印の中か（p は印の中心からの位置）。
static func _in_icon(p: Vector2, mark_kind: Kind) -> bool:
	if mark_kind == Kind.ATTACKER:
		# 上向きの矢（三角と軸）。
		var head := p.y >= -12.0 and p.y <= 0.0 and absf(p.x) <= (p.y + 12.0) * 0.9
		return head or (p.y > 0.0 and p.y <= 11.0 and absf(p.x) <= 3.5)
	# 照準: 輪と、4 方の短い線、真ん中の点。
	var r := p.length()
	if absf(r - 10.0) <= 1.8 or r <= 2.6:
		return true
	return (absf(p.x) <= 1.6 and absf(p.y) >= 7.0 and absf(p.y) <= 15.0) or (absf(p.y) <= 1.6 and absf(p.x) >= 7.0 and absf(p.x) <= 15.0)
