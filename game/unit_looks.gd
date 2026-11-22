extends RefCounted
## 駒の見た目の組の並び（docs/battle-view.md の「駒の見た目の組」）。組は丸ごと替えられる（stage_look.gd のテーマと同じ考え）。
## 組の定義は game/looks/ に 1 つずつ（look_set.gd を継ぐ）。盤の駒・アイコン・会話の姿・編成の札は、いま使っている組に従う。
## ノードに依存しない（組の定義を返すだけ）。

const LookSet := preload("res://game/looks/look_set.gd")

## 組の名前 -> 定義のスクリプト。
const SETS := {
	&"kaykit": preload("res://game/looks/kaykit_look.gd"),
	&"tokens": preload("res://game/looks/token_look.gd"),
	&"quaternius": preload("res://game/looks/quaternius_look.gd"),
	&"mini": preload("res://game/looks/mini_look.gd"),
}
const DEFAULT := &"kaykit"
## オプションの「駒の見た目」の並び（settings.gd の UNIT_LOOK の値は、この並びの番号）。
const ORDER: Array[StringName] = [&"kaykit", &"tokens", &"quaternius", &"mini"]

## 将の別の姿の名前（見た目だけ。ルールの上では将のまま。docs/story.md の「話のファイル」の king_figure）。
## どの組も、ここに挙げた名前の姿を持つ（検査が確かめる）。話のファイルは、この名前で指すので、組を替えても通る。
const KING_LOOKS: Array[StringName] = [&"skeleton_mage"]

## 名前のある人物の形の名前 -> その人の駒の種類（docs/story.md の「世界と登場人物」）。話のファイルの [cast] の姿に
## 「sniper noe」のように書くと、会話の姿と、盤でその人が乗る駒が、この形になる（battle_source.gd の cast_looks）。
## 組が形を持たない人物は、駒の種類の形のまま（いまは「人形」の組だけが持つ）。
const PERSONS := {
	&"harden": UnitKind.Id.KING,
	&"dawson": UnitKind.Id.SHIELD_TROOPER,
	&"noe": UnitKind.Id.SNIPER,
	&"marta": UnitKind.Id.MEDIC,
	&"pip": UnitKind.Id.COMMANDO,
	&"yelda": UnitKind.Id.PALADIN,
	&"ul": UnitKind.Id.PRIEST,
	&"tio": UnitKind.Id.SORCERER,
	&"seris": UnitKind.Id.SPELLBLADE,
	&"valt": UnitKind.Id.SNIPER,
	&"drill_sergeant": UnitKind.Id.PALADIN,
}

static var _active := DEFAULT
static var _instances := {}


## 名前の組の定義（知らない名前なら既定の組）。
static func of(name: StringName) -> LookSet:
	if not SETS.has(name):
		name = DEFAULT
	if not _instances.has(name):
		_instances[name] = SETS[name].new()
	return _instances[name]


## いま使っている組の名前と定義。
static func active_name() -> StringName:
	return _active


static func active() -> LookSet:
	return of(_active)


## 使う組を替える（知らない名前なら既定の組）。もう立っている駒は替わらない（次に作る駒から）。
## アプリは、場面を作るたびに、オプションの値でこれを呼ぶ（app.gd の go）。場面の途中では替えない（盤の駒とアイコンが混ざらないように）。
static func use(name: StringName) -> void:
	_active = name if SETS.has(name) else DEFAULT


## オプションの値（ORDER の番号）の組の名前（範囲の外なら既定の組）。
static func name_at(index: int) -> StringName:
	return ORDER[index] if index >= 0 and index < ORDER.size() else DEFAULT


## 盤の駒に、名前のある人物の形を割り当てる（駒の id -> PERSONS の名前）。cast は陣営ごとの人物の列
## [[{"kind": 駒の種類, "look": 人物, "king": 将か}, …], …]（battle_source.gd の cast_looks）。
## 将の人物（姿が king か、将の印 crown を付けた人）はその陣営の将に、ほかの人は、その陣営で同じ種類の駒のうち、
## まだ人物の付いていない、いちばん前（id の小さい）の駒に付ける。合う駒が無ければ付けない（会話の姿だけ）。
static func assign_people(units: Array, cast: Array) -> Dictionary:
	var assigned := {}
	var sorted := units.duplicate()
	sorted.sort_custom(func(a: Unit, b: Unit) -> bool: return a.id < b.id)
	for side in cast.size():
		for person: Dictionary in cast[side]:
			var wanted: UnitKind.Id = UnitKind.Id.KING if person["king"] else person["kind"]
			for unit: Unit in sorted:
				if unit.side == side and unit.kind == wanted and not assigned.has(unit.id):
					assigned[unit.id] = person["look"]
					break
	return assigned
