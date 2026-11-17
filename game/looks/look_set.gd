extends RefCounted
## 駒の見た目の組の土台（組ごとの定義は game/looks/ の、これを継いだもの。並びは unit_looks.gd）。
## 組は、駒の種類ごとに「形・持ち物・色の付け方・動き・大きさ」を決めて、体（unit_body.gd）を作る。
## 足元の円盤・HP の棒・進化と状態の輪・将の冠は、どの組でも駒の見た目（unit_view.gd）が同じに付ける（読み方を変えないため）。
## 組が気にするのは、体を足元の円盤（半径 0.4）に収めることと、体の高さ（body_height）を正しく返すこと。

const UnitBody := preload("res://game/unit_body.gd")
const CoreBody := preload("res://game/looks/core_body.gd")

## 駒のアイコン（tools/unit_icons.gd が、この組で写したもの）を置くディレクトリ。
var icon_dir := "res://assets/unit_icons"


## kind の駒の体を作る（陣営の色 team_color。look は将の別の姿の名前で、将でなければ空）。
## at は駒の置き場所（揺れの位相などを、駒ごとにずらすのに使う）。
func build(kind: UnitKind.Id, team_color: Color, _look: StringName, at: Vector3) -> UnitBody:
	if CoreBody.has_shape(kind):
		return core(kind, team_color, at)
	return placeholder(team_color)


## 中立の駒の体。組が中立の駒の形を持たなければ、これを使う。
func core(kind: UnitKind.Id, team_color: Color, at: Vector3) -> UnitBody:
	var body := CoreBody.new()
	body.build(kind, team_color, at)
	return body


## 組に形の無い駒の体（陣営の色のカプセル）。
func placeholder(team_color: Color) -> UnitBody:
	var body := UnitBody.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.95
	var material := StandardMaterial3D.new()
	material.albedo_color = team_color
	material.roughness = 0.9
	var capsule := MeshInstance3D.new()
	capsule.mesh = mesh
	capsule.material_override = material
	capsule.position.y = 0.475
	body.add_child(capsule)
	return body
