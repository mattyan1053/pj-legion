extends Node3D
## 盤面の見た目（game/board_view.gd）の土台: 読み込み、調整値、状態と、形と材質を作る道具。
## 見た目の種類ごとのファイル（board_*.gd）は、これを継いで順に積み重なる（board_view.gd が最後）。


const CrystalMesh := preload("res://game/crystal_mesh.gd")
const Text := preload("res://game/text.gd")
const CragMesh := preload("res://game/crag_mesh.gd")
const StageLook := preload("res://game/stage_look.gd")
const Scenery := preload("res://game/scenery.gd")
const GROUND_SHADER := preload("res://game/ground.gdshader")
const GRID_SHADER := preload("res://game/grid.gdshader")
const RenderTone := preload("res://game/render_tone.gd")
const GaugeSprite := preload("res://game/gauge_sprite.gd")
## 障害物と森のマスに置くもの、地面の色と模様、泉の石と結晶の色は、マップの見た目（stage_look.gd）が決める。
## 石の壁（StageLook.WALL）の柱と壁の幅（マス）。柱は壁より少し太い。
const WALL_PILLAR_WIDTH := 0.62
const WALL_THICKNESS := 0.46
## 壁の高さ（柱に対して）と、崩れた壁にする割合。
const WALL_HEIGHT := 0.82
const WALL_BROKEN_SHARE := 0.25
## 隣に障害物の無い 1 マスを短い壁にするとき（見た目の lone_wall）の、壁の幅（マス）と、両端の柱の太さ（素材の幅に掛ける）。
const LONE_WALL_WIDTH := 0.74
const LONE_WALL_POST := 0.2


## 塗ったマスどうしの隙間（マス目の線が見える）。
const TILE_GAP := 0.04
## 地面を盤の外へ広げる距離（マス）。霞で見えなくなるより、ずっと先まで。
const GROUND_REACH := 400.0
## 地形の色の地図の細かさ（1 マスのピクセル数）と、盤の周りに付ける平地の幅（マス）。
const MAP_SCALE := 8
const MAP_PAD := 2
## マス目の線の濃さが変わる速さ（1 秒あたり）。
const GRID_FADE_SPEED := 6.0
const NO_CELL := Vector2i(-1, -1)


## 手前の障害物をどこまで透かすか（0 = 不透明、1 = 見えない）と、その速さ。
const OCCLUDER_FADE := 0.75
const OCCLUDER_FADE_SPEED := 5.0


const COLOR_BARREL := Color("8a5a2b")
const COLOR_BARREL_BAND := Color("3a3a3e")
const COLOR_BARREL_MARK := Color("e8452e")
const COLOR_SPRING_WATER := Color("2f8fe0")
const COLOR_SPRING_CROSS := Color("2fd66b")
const COLOR_BATTERY_BASE := Color("4a4f5a")
const COLOR_BATTERY_GUN := Color("2b2e36")
const COLOR_BATTERY_MARK := Color("ffb347")
## 拠点: 黒い縁取りの上に明るい黄の輪。どの景色の地面でも沈まないよう、光に左右されない色で描く。
const COLOR_STRONGHOLD_EDGE := Color("1c1a14")
const COLOR_STRONGHOLD_MARK := Color("fff27a")
const COLOR_STRONGHOLD_FLAG := Color("f4f1e6")
## 拠点の旗の高さ（竿の足からの、旗の中心。確保 0 と、勝つ数に届いたとき）と、竿の上の数の札の大きさ。
const STRONGHOLD_FLAG_LOW := 0.75
const STRONGHOLD_FLAG_HIGH := 2.3
const STRONGHOLD_LABEL_PIXEL := 0.0009
## ポータルの色。対ごとに変える（同じ色の 2 つがつながっている）。
const PORTAL_COLORS: Array[Color] = [Color("b06cff"), Color("ff9a3c"), Color("ff5fa8"), Color("f2e85a")]
const COLOR_SMOKE := Color(0.62, 0.64, 0.68, 0.55)
## 泉の波紋（1 回の秒数、いちばん濃いときの濃さ、1 つの泉の波紋の数）。
const RIPPLE_PERIOD := 2.2
const RIPPLE_ALPHA := 0.75
const RIPPLES_PER_SPRING := 2
## ポータルの光の粒（昇りきるまでの秒数、昇る高さ、1 つのポータルの粒の数）と、面の脈の秒数。
const MOTE_PERIOD := 1.6
const MOTE_RISE := 0.9
const MOTES_PER_PORTAL := 4
const PORTAL_PULSE_PERIOD := 1.8
## 敵の全員の脅威範囲（show_danger）。塗りではなく、赤い斜線と、範囲の縁の線で描く。
## 移動の青・巡航の黄の塗りの上に重ねても、下の色が見えて、どちらも読める。
const COLOR_DANGER_STRIPE := Color(0.95, 0.12, 0.1, 0.3)
const COLOR_DANGER_EDGE := Color(1.0, 0.25, 0.18, 0.7)
## 斜線と縁の高さ。塗ったマス（駒の足元より上に塗るものも）より上。
const DANGER_LIFT := 0.07
## 縁の線の太さ（マス）。
const DANGER_EDGE_WIDTH := 0.07
## 表示したままにしている（ピン留めした）駒の攻撃範囲（show_pinned）。駒ごとに、薄い橙の塗りと、範囲の縁の橙の線。
## 敵の全員の脅威範囲（赤い斜線）とは別の色で、両方を出しても見分けられる。縁の線は、斜線の縁より少し内側に引く。
## 平地の色の明るさから、光を当てたあとの地面の明るさを見積もる数。
const GROUND_TONE_SCALE := 1.15
## マス目の線の濃さ（互換の描画での見え方。grid.gdshader の idle_alpha・active_alpha・border_alpha に渡す）。
## 線の色（grid.gdshader の line_color）。
const GRID_LINE_COLOR := Color(1.0, 1.0, 0.9)
const GRID_IDLE_ALPHA := 0.17
const GRID_ACTIVE_ALPHA := 0.46
const GRID_BORDER_ALPHA := 0.42
## 盾の耐久の棒の高さ（盾の上の板の上に浮かせる）と、駒の HP の棒に対する大きさ。
const BARRICADE_BAR_HEIGHT := 1.05
const BARRICADE_BAR_SCALE := 1.4
const COLOR_PIN_FILL := Color(1.0, 0.55, 0.1, 0.16)
const COLOR_PIN_EDGE := Color(1.0, 0.6, 0.15, 0.9)
const PIN_LIFT := 0.065
const PIN_EDGE_INSET := 0.09


var board: Board
## マップの見た目（stage_look.gd）。
var look: Dictionary = StageLook.of(StageLook.DEFAULT)


var _barrels := {}  # Vector2i -> Node3D（爆発したら取り除く）
var _field_effects := {}  # 効果の番号 -> Node3D（消えたら取り除く）
## 盾の耐久の棒（効果の番号 -> Sprite3D）と、いま出している耐久（効果の番号 -> 耐久）。
var _barricade_bars := {}
var _barricade_durability := {}
var _team_colors: Array[Color] = []
var _occluders := {}  # Vector2i -> Array[GeometryInstance3D]（岩山と木立。手前にあると駒を隠す）
var _cursor: MeshInstance3D
var _marked: MeshInstance3D
var _highlight: MultiMesh
var _danger_stripes: MultiMesh
var _danger_edges: MultiMesh
var _danger_cells: Array[Vector2i] = []
var _pin_fill: MultiMesh
var _pin_edges: MultiMesh
var _pinned_sets: Array = []
var _grid: ShaderMaterial
var _grid_instance: MeshInstance3D
var _grid_emphasis := 0.0
var _grid_emphasized := false
## 泉とポータルの動き。泉: 水面に広がる波紋（[輪, マテリアル, 位相]）。ポータル: 渦を巻いて昇る光の粒（[粒, 中心, 位相]）と、
## 脈打つ面（[マテリアル, 色]）。
var _ripples: Array = []
var _motes: Array = []
var _portal_discs: Array = []
var _stronghold_cloth: StandardMaterial3D  # 拠点の旗の布（確保を進めた陣営の色に変える）
## 拠点の旗（布と縁。確保の進み具合で竿を上る）と、竿の上の数の札（「3 / 6」）。
var _stronghold_flag: Array[Node3D] = []
var _stronghold_label: Label3D
var _stronghold_pole_foot := Vector3.ZERO
var _motion_time := 0.0
static var _noise: ImageTexture


static func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)


static func cell_of(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x), floori(point.z))


## 地面のおよその明るさ（sRGB）。半透明の重ね塗りの濃さを、描画方式でそろえるときに使う（render_tone.gd）。
func _ground_tone() -> float:
	return clampf((look[StageLook.NORMAL] as Color).get_luminance() * GROUND_TONE_SCALE, 0.2, 0.8)


func _add_part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)


## 本陣の旗。駒が乗っても見えるよう、マスの隅に立てる。
func _add_flag(center: Vector3, color: Color) -> void:
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.025
	pole_mesh.bottom_radius = 0.025
	pole_mesh.height = 1.5
	var foot := center + Vector3(-0.4, 0.0, -0.4)
	_add_mesh(pole_mesh, _material(Color("d8d2c0")), foot + Vector3(0.0, 0.75, 0.0))
	var cloth_mesh := BoxMesh.new()
	cloth_mesh.size = Vector3(0.42, 0.26, 0.03)
	var cloth := _material(color)
	cloth.emission_enabled = true
	cloth.emission = color
	cloth.emission_energy_multiplier = 0.25
	_add_mesh(cloth_mesh, cloth, foot + Vector3(0.22, 1.36, 0.0))


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


## 光に左右されない、決まった色（どの描画方式でも同じ色に見える）。
func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _overlay_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = RenderTone.overlay_color(color, _ground_tone())  # Forward+ では濃く出るぶん下げる
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _add_mesh(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	add_child(instance)
	return instance
