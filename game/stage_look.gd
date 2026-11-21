extends RefCounted
## マップの見た目（テーマ）。見た目ごとに 1 つの定義（THEMES の 1 項目。鍵は見た目の名前）で、次をまとめて決める。
## - 地面: 色（平地・森・岩場・結晶泉）と模様（石畳、乾き）。ground.gdshader に渡す。
## - 盤の上の置物: 障害物と森のマスに置くもの（素材か、コードで作った結晶）。泉の石と、結晶泉の結晶の色。board_view.gd が使う。
## - 盤の外の景色: 大きいもの（岩山など）・小さいもの（木など）・散らばるもの（石など）の候補。scenery.gd が並べる。
## - 空と霞と光: 色、日の向きと強さ。build_environment で作り、apply で当てる。
## - マップ選択のカードと、ミニマップの色（map_card.gd）も、ここの色を使う。
##
## マップを足す・素材を替えるときは、THEMES に定義を 1 つ書く（または書き換える）だけにする。
## 盤の形はルール（BoardGenerator）が決める。ここは見た目だけ。
## 見た目は名前で引く（マップの番号では引かない）。どの見た目で描くかは、対戦の画面に渡すもの（battle_source.gd の look）が決める。
## 対戦モードの生成のマップは、OF_STAGE で見た目の名前に直す。
##
## 守ること（遊びやすさが先）:
## - マスの種類（通れない・森・平地）が、どのテーマでもひと目で見分けられる。障害物は背の高い硬いもの（岩山・壁）、
##   森は木、平地は何も置かない。地面の色も 3 つで明るさを変える。
## - 本陣の陣営の色、マスの塗り分け、駒、HP の棒、起爆樽とポータルの色は、どのテーマでも変えない（読み方を変えないため）。

const CrystalMesh := preload("res://game/crystal_mesh.gd")
const BOARD_SKY := preload("res://game/board_sky.gdshader")
const RenderTone := preload("res://game/render_tone.gd")

## 空の球の半径（カメラの見える距離より内側）と、その名前（apply が探す）。
const SKY_RADIUS := 220.0
const SKY_NODE := "Sky"
## 画面の効果（オプションの「画面の効果」。光るものの光のにじみ、物の合わせ目の陰、色の調子）。
## にじむのは、この明るさを超えたところだけ（結晶、ポータル、泉、演出の光）。地面や駒はにじませない。
const GLOW_THRESHOLD := 1.0
const GLOW_INTENSITY := 0.55
## 光るもの（結晶など）の光の強さ。GLOW_THRESHOLD を超えて、にじむ。
const CRYSTAL_GLOW := 1.3

## 霞が始まる距離と、すっかり霞む距離（カメラから）。いちばん引いて盤の端から端を見ても、盤の中はほとんど霞まない。
const FOG_BEGIN := 64.0
const FOG_END := 108.0

## 色の名前（地面と空気）。
const NORMAL := &"normal"  ## 平地
const FOREST := &"forest"  ## 森の地面
const OBSTACLE := &"obstacle"  ## 岩場の地面
const FONT := &"font"  ## 結晶泉の地面
const HAZE := &"haze"  ## 霞と、地平の空
const SKY := &"sky"  ## 高い空
const SUN := &"sun"  ## 日の光
const AMBIENT := &"ambient"  ## まわりの光
## 置物の色。
const CRYSTAL := &"crystal"  ## 結晶泉の結晶
const SPRING_STONE := &"spring_stone"  ## 回復の泉の石の縁と札の柱

## 数の名前。
const SUN_PITCH := &"sun_pitch"  ## 日の高さ（度。負で見下ろす）
const SUN_YAW := &"sun_yaw"  ## 日の向き（度）
const SUN_ENERGY := &"sun_energy"
const AMBIENT_ENERGY := &"ambient_energy"
const PAVING := &"paving"  ## 地面の石畳の濃さ（0 = 無し）
const DRY := &"dry"  ## 地面の、ところどころ枯れた色に寄せる濃さ
## 無くてよい数（書かなければ 0）。
const STRATA := &"strata"  ## 地面の、掘り下げた段々（露天掘りの棚）の濃さ
const CRACKS := &"cracks"  ## 地面の、ひび割れの濃さ
const SEAM_GLOW := &"seam_glow"  ## 盤の向こう（プレイヤー2 の本陣の先）の地面を横切る、光る裂け目の明るさ

## 置物の定義の名前。
const OBSTACLE_PROPS := &"obstacle_props"  ## 障害物のマス（下の「置き方」）
const FOREST_PROPS := &"forest_props"  ## 森のマス（下の「置き方」）
const SCENERY := &"scenery"  ## 盤の外（BIG・SMALL・SCATTER の候補と、TINT）
const BIG := &"big"
const SMALL := &"small"
const SCATTER := &"scatter"
const TINT := &"tint"
const BIG_SPREAD := &"big_spread"  ## 無くてよい。大きいものの尾根を太らせる量（書かなければ 0。0.3 で、ほぼ倍の数）
const SMALL_SHARE := &"small_share"  ## 無くてよい。小さいものを置く割合（書かなければ 1 = 森のように詰めて）

## マスの置き方（OBSTACLE_PROPS・FOREST_PROPS）:
##   {style, props: [素材, …], tint: Color, crystals?: Color, と style ごとの数}
## style:
##   SINGLE: マスごとに props から 1 つを選んで、素材の大きさの scale 倍で置く。向きは 60 度刻みでばらす。
##   WALL: マスの真ん中に柱（props[0]）を立て、右と下のマスも同じ種類なら、間を壁（props[1]、ときどき props[2]）でつなぐ。
##         続いた障害物が、1 本の石の壁に見える。height は柱の高さ（マス）。
##   CRAG: 辺で接する障害物のかたまりを、1 つの岩山に見せる（crag_mesh.gd がコードで形を作る。props は使わない）。
##         内側ほど高く、縁は低い崖。low・cliff・top は面の色（崖の下・崖の上・上を向いた面）。
## crystals があれば、その色の結晶の群れを、置いたものの上に生やす（光る。CRAG は、かたまりの内側のところどころに）。
const SINGLE := &"single"
const WALL := &"wall"
const CRAG := &"crag"

## 素材: {scene: パス, height: 大きさ 1 のときの高さ} か、{crystal: Color, height: 1.0}（コードで作る結晶の群れ。crystal_mesh.gd）。
## size があれば、景色に置くときの大きさに掛ける（大きく・小さく見せたいもの）。height は検査が素材と突き合わせる。
## tint があれば、景色に置くときの色に掛ける（景色の色 TINT と合わせて）。
const HEX := "res://assets/kaykit/medieval-hexagon/"
const DUNGEON := "res://assets/kaykit/dungeon-remastered/"
const TREES_A := {"scene": HEX + "trees_A_small.gltf", "height": 1.09}
const TREES_B := {"scene": HEX + "trees_B_small.gltf", "height": 0.92}
const TREES_B_MEDIUM := {"scene": HEX + "trees_B_medium.gltf", "height": 1.15}
const MOUNTAIN_A := {"scene": HEX + "mountain_A.gltf", "height": 1.43}
const MOUNTAIN_B := {"scene": HEX + "mountain_B.gltf", "height": 1.77}
const MOUNTAIN_C := {"scene": HEX + "mountain_C.gltf", "height": 1.51}
const ROCK_A := {"scene": HEX + "rock_single_A.gltf", "height": 0.07}
const ROCK_C := {"scene": HEX + "rock_single_C.gltf", "height": 0.19}
const ROCK_E := {"scene": HEX + "rock_single_E.gltf", "height": 0.19, "size": 0.5}
const PILLAR := {"scene": DUNGEON + "pillar.glb", "height": 4.0}
const STONE_WALL := {"scene": DUNGEON + "wall.glb", "height": 4.0}
const STONE_WALL_BROKEN := {"scene": DUNGEON + "wall_broken.glb", "height": 4.0}
const STONE_WALL_HALF := {"scene": DUNGEON + "wall_half.glb", "height": 4.0}
const COLUMN := {"scene": DUNGEON + "column.glb", "height": 1.4}
const BARRIER := {"scene": DUNGEON + "barrier_column.glb", "height": 1.4}
const RUBBLE := {"scene": DUNGEON + "rubble_half.glb", "height": 3.5}
const RUBBLE_LARGE := {"scene": DUNGEON + "rubble_large.glb", "height": 3.5}
const TREES_A_CUT := {"scene": HEX + "trees_A_cut.gltf", "height": 0.2, "size": 0.16}
const MINE := {"scene": HEX + "building_mine_yellow.gltf", "height": 1.14, "size": 0.42, "tint": Color("c8b8a8")}
const SCAFFOLDING := {"scene": HEX + "building_scaffolding.gltf", "height": 1.3, "size": 0.42, "tint": Color("c8b8a8")}
const WHEELBARROW := {"scene": HEX + "wheelbarrow.gltf", "height": 0.19, "size": 0.4}
const STONE_PILE := {"scene": HEX + "resource_stone.gltf", "height": 0.28, "size": 0.5}
const CRATE := {"scene": HEX + "crate_A_big.gltf", "height": 0.21, "size": 0.5, "tint": Color("b8a890")}
const LONG_CRATE := {"scene": HEX + "crate_long_A.gltf", "height": 0.15, "size": 0.35, "tint": Color("b8a890")}
const CRYSTAL_VIOLET := {"crystal": Color("9465f0"), "height": 1.0}
## 盤の上の結晶の岩山の結晶。ポータル（紫 b06cff）・中ボス（紫）・結晶泉（水色）と見分けられる青。
const CRAG_CRYSTAL := Color("4f63e8")
const CRYSTAL_CYAN := {"crystal": Color("5fe0f5"), "height": 1.0}

## どのマップの見た目も持つ項目（検査が確かめる）。
const KEYS: Array[StringName] = [
	NORMAL, FOREST, OBSTACLE, FONT, HAZE, SKY, SUN, AMBIENT, CRYSTAL, SPRING_STONE,
	SUN_PITCH, SUN_YAW, SUN_ENERGY, AMBIENT_ENERGY, PAVING, DRY, OBSTACLE_PROPS, FOREST_PROPS, SCENERY,
]

## 盤の外の景色に掛ける色の、どのテーマにも共通の分（盤の上の木立や岩山より沈ませる）。
const SCENERY_SHADE := Color(0.84, 0.88, 0.86)

## 見た目の名前。対戦モードのマップの名前とは別の名前の空間（マップ → 見た目は OF_STAGE、ストーリーの話 → 見た目は話の LOOK）。
## 同じ見た目を、いくつものマップや話で使い回せる。マップの見た目を替えるときは OF_STAGE を書き換え、見た目そのものは替えない。
const GRASSLAND := &"grassland"  ## 草原（中央平原）
const STONE_WALLS := &"stone_walls"  ## 石の壁（迷宮回廊、ストーリーの尾根の小道）
const CRYSTAL_FOREST := &"crystal_forest"  ## 結晶の森（双子結晶、ストーリーの結晶の岩山）
const QUARRY := &"quarry"  ## 採掘場（結晶の採掘場）
const SEAM := &"seam"  ## 縫い目の谷
## 名前を渡されないとき・知らない名前のときの見た目。
const DEFAULT := GRASSLAND
## 対戦モードの生成のマップ（BoardGenerator.Stage）-> 見た目の名前。
const OF_STAGE := {
	BoardGenerator.Stage.PLAIN: GRASSLAND,
	BoardGenerator.Stage.LABYRINTH: STONE_WALLS,
	BoardGenerator.Stage.TWIN_SPRINGS: CRYSTAL_FOREST,
}

const THEMES := {
	# 中央平原: いつもの草原。明るい若草色、昼の白い光。森と、灰色の岩山（固まった障害物は 1 つの岩山に）。
	GRASSLAND: {
		NORMAL: Color("5a9549"), FOREST: Color("386a38"), OBSTACLE: Color("767b84"), FONT: Color("3fa9bd"),
		HAZE: Color("b4cbdc"), SKY: Color("4f86c9"), SUN: Color("fff3dc"), AMBIENT: Color("a9bbd8"),
		SUN_PITCH: -48.0, SUN_YAW: -35.0, SUN_ENERGY: 1.15, AMBIENT_ENERGY: 0.5,
		PAVING: 0.0, DRY: 0.45,
		CRYSTAL: Color("4fd8f0"), SPRING_STONE: Color("b9bcc0"),
		OBSTACLE_PROPS: {
			"style": CRAG, "props": [], "tint": Color.WHITE,
			"low": Color("464a52"), "cliff": Color("6c717b"), "top": Color("878d80"),
		},
		FOREST_PROPS: {"style": SINGLE, "props": [TREES_A, TREES_B], "scale": 0.62, "tint": Color.WHITE},
		SCENERY: {BIG: [MOUNTAIN_A], SMALL: [TREES_A, TREES_B], SCATTER: [], TINT: Color.WHITE},
	},
	# 迷宮回廊: 遺跡。石畳の乾いた地面に、石の壁と柱が続く。盤の外は崩れた石組みと柱、枯れた木、砂色の岩山。
	# 夕方寄りの低い金色の光と、砂ぼこりの霞。
	STONE_WALLS: {
		NORMAL: Color("9a8f74"), FOREST: Color("5d7c38"), OBSTACLE: Color("5a5246"), FONT: Color("3fa9bd"),
		HAZE: Color("d9c9a6"), SKY: Color("7f9bb4"), SUN: Color("ffdcaa"), AMBIENT: Color("c8b8a0"),
		SUN_PITCH: -42.0, SUN_YAW: -62.0, SUN_ENERGY: 1.25, AMBIENT_ENERGY: 0.5,
		PAVING: 1.0, DRY: 0.8,
		CRYSTAL: Color("4fd8f0"), SPRING_STONE: Color("d8c8a4"),
		OBSTACLE_PROPS: {"style": WALL, "props": [PILLAR, STONE_WALL, STONE_WALL_BROKEN], "height": 1.0, "tint": Color("efe2c8")},
		FOREST_PROPS: {"style": SINGLE, "props": [TREES_A, TREES_B], "scale": 0.62, "tint": Color("c8c890")},
		SCENERY: {
			BIG: [MOUNTAIN_C, {"scene": DUNGEON + "wall_broken.glb", "height": 4.0, "size": 0.45}, RUBBLE_LARGE],
			SMALL: [PILLAR, COLUMN, STONE_WALL_HALF],
			SCATTER: [RUBBLE, ROCK_A, BARRIER],
			TINT: Color("e8d8b8"),
		},
	},
	# 双子結晶: 結晶の森。夜明けの薄紫の霞と、低い桃色の光。苔むした暗い青緑の地面に、青い結晶の生えた暗い紫の岩山、
	# 暗い針葉樹の森。盤の外にも結晶が光る。
	CRYSTAL_FOREST: {
		NORMAL: Color("3c6f68"), FOREST: Color("1d4440"), OBSTACLE: Color("4a4468"), FONT: Color("46bcd6"),
		HAZE: Color("b4a3cf"), SKY: Color("3a3f86"), SUN: Color("ffc8b8"), AMBIENT: Color("8f9ad0"),
		SUN_PITCH: -30.0, SUN_YAW: 40.0, SUN_ENERGY: 1.1, AMBIENT_ENERGY: 0.55,
		PAVING: 0.0, DRY: 0.0,
		CRYSTAL: Color("5fe0f5"), SPRING_STONE: Color("8c8aa8"),
		OBSTACLE_PROPS: {
			"style": CRAG, "props": [], "tint": Color.WHITE, "crystals": CRAG_CRYSTAL,
			"low": Color("1f1d2e"), "cliff": Color("3f3b5a"), "top": Color("5b5a7c"),
		},
		FOREST_PROPS: {"style": SINGLE, "props": [TREES_B, TREES_A], "scale": 0.64, "tint": Color("6a9aa8")},
		SCENERY: {
			BIG: [MOUNTAIN_B, {"crystal": Color("9465f0"), "height": 1.0, "size": 0.6}],
			SMALL: [TREES_B, TREES_B_MEDIUM, CRYSTAL_VIOLET, CRYSTAL_CYAN],
			SCATTER: [ROCK_C, CRYSTAL_CYAN],
			TINT: Color("8a98c0"),
		},
	},
	# 結晶の採掘場: 露天掘り。掘り返した赤茶の土が段々に下がり、障害物は切り出した岩の山に、掘り残した青い結晶がのぞく。
	# 盤の外は、坑口、足場、木箱と樽の山、石の山、手押し車、切り株。高い日の白い光と、土ぼこりの霞。
	QUARRY: {
		NORMAL: Color("806850"), FOREST: Color("56663a"), OBSTACLE: Color("3f322d"), FONT: Color("3fa9bd"),
		HAZE: Color("d9c2ad"), SKY: Color("6a94bc"), SUN: Color("fff4e2"), AMBIENT: Color("c2b3a8"),
		SUN_PITCH: -62.0, SUN_YAW: 18.0, SUN_ENERGY: 1.25, AMBIENT_ENERGY: 0.5,
		PAVING: 0.0, DRY: 0.3, STRATA: 1.0,
		CRYSTAL: Color("4fd8f0"), SPRING_STONE: Color("c9b8a4"),
		OBSTACLE_PROPS: {
			"style": CRAG, "props": [], "tint": Color.WHITE, "crystals": CRAG_CRYSTAL,
			"low": Color("3b2a24"), "cliff": Color("8a5f44"), "top": Color("ab8a6a"),
		},
		FOREST_PROPS: {"style": SINGLE, "props": [TREES_A, TREES_B], "scale": 0.6, "tint": Color("b9b46e")},
		SCENERY: {
			BIG: [MOUNTAIN_C, MOUNTAIN_A, MOUNTAIN_C, MINE, SCAFFOLDING],
			SMALL: [CRATE, STONE_PILE, LONG_CRATE, WHEELBARROW, TREES_A_CUT, STONE_PILE],
			SCATTER: [ROCK_C, STONE_PILE, {"crystal": CRAG_CRYSTAL, "height": 1.0, "size": 0.8}],
			TINT: Color("d8c0a8"), SMALL_SHARE: 0.5,
		},
	},
	# 縫い目の谷: 糸を抜かれて、いちばん傷んだ所。灰色のひび割れた地面に、結晶の抜けた暗い岩の帯。森は枯れかけた木立。
	# 盤の外は、両側から迫る暗い山並みと、割れ残った結晶。宵の暗い菫の霞と冷たい光。プレイヤー2 の本陣の向こうの地面を、光る裂け目（縫い目）が横切る。
	SEAM: {
		NORMAL: Color("676b72"), FOREST: Color("3e4a44"), OBSTACLE: Color("2c2a33"), FONT: Color("46bcd6"),
		HAZE: Color("5a4c84"), SKY: Color("151433"), SUN: Color("d6dcff"), AMBIENT: Color("9c94c8"),
		SUN_PITCH: -52.0, SUN_YAW: -150.0, SUN_ENERGY: 1.0, AMBIENT_ENERGY: 0.6,
		PAVING: 0.0, DRY: 0.0, CRACKS: 1.0, SEAM_GLOW: 1.0,
		CRYSTAL: Color("5fe0f5"), SPRING_STONE: Color("9a98b0"),
		OBSTACLE_PROPS: {
			"style": CRAG, "props": [], "tint": Color.WHITE,
			"low": Color("17161d"), "cliff": Color("3a3944"), "top": Color("6f7180"),
		},
		FOREST_PROPS: {"style": SINGLE, "props": [TREES_A, TREES_B], "scale": 0.6, "tint": Color("8a9484")},
		SCENERY: {
			BIG: [MOUNTAIN_B, MOUNTAIN_A, MOUNTAIN_B, {"crystal": Color("9465f0"), "height": 1.0, "size": 0.5}],
			SMALL: [TREES_A, ROCK_E, CRYSTAL_VIOLET, ROCK_C],
			SCATTER: [ROCK_C, ROCK_A, CRYSTAL_CYAN],
			TINT: Color("7c7a96"), SMALL_SHARE: 0.25, BIG_SPREAD: 0.3,
		},
	},
}

static var _meshes := {}  # 素材の定義の文字列 -> Mesh
static var _materials := {}  # [素材, 色] -> Material


## 名前 look_name の見た目。知らない名前なら、既定（DEFAULT）。
static func of(look_name: StringName) -> Dictionary:
	return THEMES.get(look_name, THEMES[DEFAULT])


## 対戦モードの生成のマップ stage の見た目の名前。知らないマップなら、既定（DEFAULT）。
static func name_of_stage(stage: int) -> StringName:
	return OF_STAGE.get(stage, DEFAULT)


## 素材の形（シーンの中の形はどれも 1 つで、原点に置いてある）。結晶の群れはコードで作る。1 回だけ読む。
static func mesh_of(prop: Dictionary) -> Mesh:
	var key := _key(prop)
	if not _meshes.has(key):
		if prop.has("crystal"):
			_meshes[key] = CrystalMesh.cluster()
		else:
			var root: Node = (load(prop.scene) as PackedScene).instantiate()
			var found: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
			_meshes[key] = found.mesh
			root.free()
	return _meshes[key]


## 素材の色（素材の色に tint を掛ける）。結晶は光る。同じ素材と色なら、同じものを返す。
static func material_of(prop: Dictionary, tint: Color) -> Material:
	var key := [_key(prop), tint]
	if not _materials.has(key):
		var material: StandardMaterial3D
		if prop.has("crystal"):
			material = crystal_material(prop.crystal)
		else:
			material = mesh_of(prop).surface_get_material(0).duplicate()
			material.albedo_color = material.albedo_color * tint
		_materials[key] = material
	return _materials[key]


## 結晶の色（光る、つやのある面。画面の効果があれば、光がにじむ）。
static func crystal_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = CRYSTAL_GLOW
	material.roughness = 0.25
	return material


static func _key(prop: Dictionary) -> String:
	return str(prop.get("scene", prop.get("crystal")))


## 画面の効果を使うか（オプション。アプリの入口が set_effects で決める）。
static var effects := true
static var _environments: Array[WeakRef] = []


## 画面の効果を入れる・切る。いま出ている景色にも、すぐ効く。
static func set_effects(on: bool) -> void:
	effects = on
	var alive: Array[WeakRef] = []
	for ref in _environments:
		var environment := ref.get_ref() as Environment
		if environment != null:
			_apply_effects(environment)
			alive.append(ref)
	_environments = alive


static func _apply_effects(environment: Environment) -> void:
	environment.ssao_enabled = effects
	environment.glow_enabled = effects
	environment.adjustment_enabled = effects


## 空・霞・光を parent に足す（タイトルと対戦設定の場面の背景も、同じ景色にする。backdrop.gd）。
## 色と光の向きは、中央平原のもの。マップの見た目は apply で当てる。
static func build_environment(parent: Node) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if RenderTone.is_forward():  # 互換の描画で決めた見え方に寄せる（render_tone.gd）
		environment.tonemap_mode = RenderTone.FORWARD_TONEMAP
		environment.tonemap_exposure = RenderTone.FORWARD_EXPOSURE
	# 遠くの地面と景色は、空の色の霞に溶かす（盤の外の端が、ぷつりと切れて見えないように）。
	# 盤の中は、いちばん引いても霞まない距離から始める。
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_sun_scatter = 0.0
	environment.fog_depth_begin = FOG_BEGIN
	environment.fog_depth_end = FOG_END
	environment.fog_depth_curve = 1.6
	# 画面の効果: 光るものだけを、控えめににじませる。色は、ほんの少し締める。
	environment.glow_hdr_threshold = GLOW_THRESHOLD
	environment.glow_intensity = GLOW_INTENSITY
	environment.glow_bloom = 0.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.04
	_apply_effects(environment)
	_environments.append(weakref(environment))

	var world := WorldEnvironment.new()
	world.environment = environment
	parent.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	parent.add_child(sun)

	# 空: 大きな球の内側に描く（低く構えて引いたとき、地平の上に見える）。
	var dome := SphereMesh.new()
	dome.radius = SKY_RADIUS
	dome.height = SKY_RADIUS * 2.0
	dome.radial_segments = 32
	dome.rings = 16
	var material := ShaderMaterial.new()
	material.shader = BOARD_SKY
	var sky := MeshInstance3D.new()
	sky.name = SKY_NODE
	sky.mesh = dome
	sky.material_override = material
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.extra_cull_margin = 4000.0  # カメラがどこにいても描く
	parent.add_child(sky)
	apply(parent, of(DEFAULT))


## マップの見た目（of）の霞・空・光を、build_environment で足したものに当てる。
static func apply(parent: Node, look: Dictionary) -> void:
	for node in parent.get_children():
		var world := node as WorldEnvironment
		if world != null:
			world.environment.background_color = look[HAZE]
			world.environment.fog_light_color = look[HAZE]
			world.environment.ambient_light_color = look[AMBIENT]
			world.environment.ambient_light_energy = look[AMBIENT_ENERGY] * RenderTone.ambient_scale()
		var sun := node as DirectionalLight3D
		if sun != null:
			sun.light_color = look[SUN]
			sun.light_energy = look[SUN_ENERGY]
			sun.rotation_degrees = Vector3(look[SUN_PITCH], look[SUN_YAW], 0.0)
		if node.name == SKY_NODE:
			var material := (node as MeshInstance3D).material_override as ShaderMaterial
			material.set_shader_parameter(&"zenith", look[SKY])
			material.set_shader_parameter(&"horizon", look[HAZE])
			material.set_shader_parameter(&"sun_color", look[SUN])
			var pitch := deg_to_rad(float(look[SUN_PITCH]))
			var yaw := deg_to_rad(float(look[SUN_YAW]))
			material.set_shader_parameter(&"sun_direction", Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Vector3.BACK)
