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
const DEFAULT := &"quaternius"
## オプションの「駒の見た目」の並び（settings.gd の UNIT_LOOK の値は、この並びの番号）。
const ORDER: Array[StringName] = [&"kaykit", &"tokens", &"quaternius", &"mini"]

## 将の別の姿の名前（見た目だけ。ルールの上では将のまま。docs/story.md の「話のファイル」の king_figure）。
## どの組も、ここに挙げた名前の姿を持つ（検査が確かめる）。話のファイルは、この名前で指すので、組を替えても通る。
const KING_LOOKS: Array[StringName] = [&"skeleton_mage"]

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
