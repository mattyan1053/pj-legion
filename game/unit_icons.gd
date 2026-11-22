extends RefCounted
## 駒のアイコン（小さい絵）。絵は描かず、駒の 3D の形（unit_view.gd）を写した PNG（tools/unit_icons.gd が作る）を使う。
## 種類 × 陣営の色（青・赤。中立の駒は中立の色だけ）× 進化の前後。ノードに依存しない（テクスチャを返すだけ）。
## 絵は、いま使っている駒の見た目の組（unit_looks.gd）のもの（組ごとのディレクトリ。組の定義の icon_dir）。

## 書き出す大きさ（px）。
const ICON_SIZE := 96
## 陣営（Unit.Side の値。2 は中立）ごとの色。対戦の画面の陣営の色（battle_screen.gd の TEAM_COLORS）と同じ。
const COLORS: Array[Color] = [Color("3a7bd5"), Color("d64545"), Color("e0b83a")]
const SIDE_NAMES: Array[String] = ["blue", "red", "neutral"]
const NEUTRAL := 2

const UnitLooks := preload("res://game/unit_looks.gd")

static var _cache := {}


## 写す組み合わせ（[種類, 陣営, 進化したか, 将の別の姿] の列）。人の駒（将と雇える駒）と魔物は青と赤、進化は進化する駒だけ（将と魔物を除く）。
## 中立の駒は中立の色だけ。将は、別の姿（unit_looks.gd の KING_LOOKS）も青と赤。
## look_set は駒の見た目の組の名前（空なら、いま使っている組）。人物の形は、その組が持つ人物だけ。
static func variants(look_set := &"") -> Array:
	var looks := UnitLooks.active() if look_set == &"" else UnitLooks.of(look_set)
	var list: Array = []
	for kind: UnitKind.Id in UnitKind.Id.values():
		if UnitKind.is_neutral(kind):
			list.append([kind, NEUTRAL, false, &""])
			continue
		for side in 2:
			list.append([kind, side, false, &""])
			if evolves(kind):
				list.append([kind, side, true, &""])
			if kind == UnitKind.Id.KING:
				for look: StringName in UnitLooks.KING_LOOKS:
					list.append([kind, side, false, look])
	# 名前のある人物の形（PERSONS）。進化の前後とも（盤で進化することがある。会話の姿も進化後を書ける）。
	for person: StringName in UnitLooks.PERSONS:
		if not looks.has_person(person):
			continue
		for side in 2:
			for evolved: bool in [false, true]:
				list.append([UnitLooks.PERSONS[person], side, evolved, person])
	return list


## 進化する種類か（進化後のアイコンがあるか）。
static func evolves(kind: UnitKind.Id) -> bool:
	return kind != UnitKind.Id.KING and not UnitKind.is_monster(kind)


## look は将の別の姿（将でない駒と、知らない名前には付けない）か、名前のある人物の形（どの駒でも、人物の名前のファイル）。
static func file_name(kind: UnitKind.Id, side: int, evolved := false, look := &"") -> String:
	var name := String(UnitKind.Id.keys()[kind]).to_lower()
	if UnitLooks.PERSONS.has(look):
		name = "person_" + String(look)
	elif kind == UnitKind.Id.KING and UnitLooks.KING_LOOKS.has(look):
		name += "_" + String(look)
	return "%s_%s%s.png" % [name, SIDE_NAMES[side], "_evolved" if evolved else ""]


## kind の駒のアイコン。side は陣営（Unit.Side の値。中立の駒は何を渡しても中立の色）。evolved は進化したか（足元に金の輪）。
## look は将の別の姿（unit_looks.gd の KING_LOOKS。将でなければ見ない）。無ければ null（呼ぶ側は、絵を出さずに文字だけにする）。
static func texture(kind: UnitKind.Id, side := 0, evolved := false, look := &"") -> Texture2D:
	var neutral := UnitKind.is_neutral(kind)
	var person := UnitLooks.PERSONS.has(look)
	# 人物の形は、将の人物でも進化の前後の絵がある（その人の種類で写す）。
	var shown_evolved := evolved and not neutral and (person or evolves(kind))
	var key := file_name(kind, NEUTRAL if neutral else clampi(side, 0, 1), shown_evolved, look)
	var path := "%s/%s" % [UnitLooks.active().icon_dir, key]
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	if _cache[path] == null and person:
		return texture(kind, side, evolved)  # 人物の形を持たない組は、種類の絵
	return _cache[path]


## 胸から上を切り出す四角（ICON_SIZE の絵の中の px）。小さく出す所（対戦の途中の台詞）で、顔が読めるように。
const BUST := Rect2(14.0, 0.0, 68.0, 68.0)


## kind の駒のアイコンの、胸から上（BUST）。絵が無ければ null。
static func bust(kind: UnitKind.Id, side := 0, evolved := false, look := &"") -> Texture2D:
	var whole := texture(kind, side, evolved, look)
	if whole == null:
		return null
	var key := "bust:%s" % whole.resource_path
	if not _cache.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = whole
		atlas.region = BUST
		_cache[key] = atlas
	return _cache[key]


## アイコンを出す TextureRect（size px の四角）。絵が無ければ空の四角（並びは崩さない）。
## look は将の別の姿（texture と同じ）。
static func rect(kind: UnitKind.Id, side := 0, evolved := false, size := 48.0, look := &"") -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture(kind, side, evolved, look)
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_meta(&"icon_kind", kind)
	return icon
