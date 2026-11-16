extends RefCounted
## 駒のアイコン（小さい絵）。絵は描かず、駒の 3D の形（unit_view.gd）を写した PNG（assets/unit_icons/。tools/unit_icons.gd が作る）を使う。
## 種類 × 陣営の色（青・赤。中立の駒は中立の色だけ）× 進化の前後。ノードに依存しない（テクスチャを返すだけ）。

## 書き出す大きさ（px）。
const ICON_SIZE := 96
const DIR := "res://assets/unit_icons"
## 陣営（Unit.Side の値。2 は中立）ごとの色。対戦の画面の陣営の色（battle_screen.gd の TEAM_COLORS）と同じ。
const COLORS: Array[Color] = [Color("3a7bd5"), Color("d64545"), Color("e0b83a")]
const SIDE_NAMES: Array[String] = ["blue", "red", "neutral"]
const NEUTRAL := 2

static var _cache := {}


## 写す組み合わせ（[種類, 陣営, 進化したか] の列）。人の駒（将と雇える駒）と魔物は青と赤、進化は進化する駒だけ（将と魔物を除く）。
## 中立の駒は中立の色だけ。
static func variants() -> Array:
	var list: Array = []
	for kind: UnitKind.Id in UnitKind.Id.values():
		if UnitKind.is_neutral(kind):
			list.append([kind, NEUTRAL, false])
			continue
		for side in 2:
			list.append([kind, side, false])
			if _evolves(kind):
				list.append([kind, side, true])
	return list


## 進化する種類か（進化後のアイコンがあるか）。
static func _evolves(kind: UnitKind.Id) -> bool:
	return kind != UnitKind.Id.KING and not UnitKind.is_monster(kind)


static func file_name(kind: UnitKind.Id, side: int, evolved := false) -> String:
	return "%s_%s%s.png" % [String(UnitKind.Id.keys()[kind]).to_lower(), SIDE_NAMES[side], "_evolved" if evolved else ""]


## kind の駒のアイコン。side は陣営（Unit.Side の値。中立の駒は何を渡しても中立の色）。evolved は進化したか（足元に金の輪）。
## 無ければ null（呼ぶ側は、絵を出さずに文字だけにする）。
static func texture(kind: UnitKind.Id, side := 0, evolved := false) -> Texture2D:
	var neutral := UnitKind.is_neutral(kind)
	var key := file_name(kind, NEUTRAL if neutral else clampi(side, 0, 1), evolved and not neutral and _evolves(kind))
	if not _cache.has(key):
		var path := "%s/%s" % [DIR, key]
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]


## アイコンを出す TextureRect（size px の四角）。絵が無ければ空の四角（並びは崩さない）。
static func rect(kind: UnitKind.Id, side := 0, evolved := false, size := 48.0) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture(kind, side, evolved)
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_meta(&"icon_kind", kind)
	return icon
