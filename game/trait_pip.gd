extends RefCounted
## 軍略の小さな印（docs/troop-traits.md の「対戦の画面」）。隣り合うことで効く軍略が、いま効いている兵の足元に出す。
## - 盾: 攻撃で受けるダメージが減る（隊列・守護）
## - 十字: 番の始めに回復する（補給線）
## 色は軍略の軍の色に暗い縁。動かず、盤の上の大きさで出す（引けば小さくなる）。兵どうしを線で結ばない
## （線は駒の上に被さり、密集すると網になる。人間の感想。Issue #46 の 11/28）。
## 同じ印を薄くして、動かす先のマスにも置く（そこへ動けば効く。trait_links.gd の set_spots）。

enum Kind { NONE, SHIELD, CROSS }

## 絵の大きさ（px）と、1 px の盤の上の大きさ（印は 0.36 m。足元の円盤の半径は 0.4 m）。
const SIDE := 40
const PIXEL := 0.009
## 足元の印の置き場所（駒の足元から。画面の右下。HP の棒の右、隣のマスの円盤の手前）。
const FOOT_OFFSET := Vector2(40.0, 2.0)
const FOOT_LIFT := 0.1
const COLOR_RIM := Color(0.06, 0.05, 0.08)
## 縁の太さ（px）。
const RIM := 4.5

static var _textures: Dictionary = {}


## 印の札を作る（いつもカメラを向く。駒や木に隠れない）。
static func make() -> Sprite3D:
	var pip := Sprite3D.new()
	pip.pixel_size = PIXEL
	pip.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pip.no_depth_test = true
	pip.shaded = false
	pip.render_priority = 2
	pip.visible = false
	return pip


## 印の絵（形と色ごとに 1 枚を使い回す）。
static func texture(kind: Kind, color: Color) -> Texture2D:
	var key := "%d:%s" % [kind, color.to_html()]
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(_draw(kind, color))
	return _textures[key]


## 軍略 id が、いま効いている兵の足元に出す印（出さない軍略なら NONE）。
static func kind_of(id: int) -> Kind:
	if Traits.shields(id):
		return Kind.SHIELD
	return Kind.CROSS if id == Traits.Id.SUPPLY else Kind.NONE


static func _draw(kind: Kind, color: Color) -> Image:
	var image := Image.create_empty(SIDE, SIDE, false, Image.FORMAT_RGBA8)
	var fill := color.lightened(0.15)
	for y in SIDE:
		for x in SIDE:
			# 形までの距離（px。負なら中）を 3×3 で取って、縁をなめらかにする。
			var body := 0.0
			var rim := 0.0
			for sy in 3:
				for sx in 3:
					var p := Vector2(x + (sx + 0.5) / 3.0, y + (sy + 0.5) / 3.0) - Vector2(SIDE, SIDE) / 2.0
					var d := _shield(p) if kind == Kind.SHIELD else _cross(p)
					body += 1.0 if d <= -RIM else 0.0
					rim += 1.0 if d <= 0.0 else 0.0
			if rim > 0.0:
				image.set_pixel(x, y, Color(COLOR_RIM.lerp(fill, body / rim), rim / 9.0))
	return image


## 盾（上が平らで、下が尖る）までの距離。
static func _shield(p: Vector2) -> float:
	var half := 13.0
	var top := -15.0
	var side := absf(p.x) - half
	# 下の縁は、真ん中へ向けて下がる放物線。
	var bottom := p.y - (17.0 - 22.0 * pow(absf(p.x) / half, 2.0)) if absf(p.x) < half else 1.0
	return maxf(maxf(side, top - p.y), bottom * 0.75)


## 十字までの距離。
static func _cross(p: Vector2) -> float:
	var arm := 16.0
	var half := 6.5
	var a := maxf(absf(p.x) - arm, absf(p.y) - half)
	var b := maxf(absf(p.x) - half, absf(p.y) - arm)
	return minf(a, b)
