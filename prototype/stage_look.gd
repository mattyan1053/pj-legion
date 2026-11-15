extends RefCounted
## ステージごとの色合い（地面の色、霞と空の色、光の色）。盤の形はルール（BoardGenerator）が決め、ここは色だけを決める。
## 素材は替えない（木と岩山の形は同じ）。地面の色と、空気の色（霞・光）で、どのステージかが一目で分かるようにする。
## 空・霞・光の組み立て（build_environment）も、ここに置く（対戦と、タイトル・対戦の設定の背景が同じ景色になる）。
##
## - 中央平原: 明るい若草色。昼の白い光。
## - 迷宮回廊: 乾いたオリーブ色の地面と、暖かい石の色。夕方寄りの、砂ぼこりの霞。
## - 双子結晶: 青みのある緑の地面と、青い石。結晶の泉の、ひんやりした霞。
##
## 本陣の陣営の色、マスの塗り分け、駒、HP の棒の色は、どのステージでも変えない（読み方を変えないため）。

## 空と、遠くの霞の色（build_environment の始めの色。ステージの色合いは apply で当てる）。
const COLOR_HAZE := Color("b4cbdc")
## 霞が始まる距離と、すっかり霞む距離（カメラから）。いちばん引いて盤の端から端を見ても、盤の中はほとんど霞まない。
const FOG_BEGIN := 64.0
const FOG_END := 108.0

## 色の名前。
const NORMAL := &"normal"  ## 平地
const FOREST := &"forest"  ## 森の地面
const OBSTACLE := &"obstacle"  ## 岩場の地面
const FONT := &"font"  ## 結晶泉の地面
const HAZE := &"haze"  ## 霞と空
const SUN := &"sun"  ## 日の光
const AMBIENT := &"ambient"  ## まわりの光

const LOOKS := {
	BoardGenerator.Stage.PLAIN: {
		NORMAL: Color("5f9f4e"), FOREST: Color("3a6c38"), OBSTACLE: Color("767b84"), FONT: Color("3fa9bd"),
		HAZE: Color("b4cbdc"), SUN: Color("ffffff"), AMBIENT: Color("b8c4d6"),
	},
	BoardGenerator.Stage.LABYRINTH: {
		NORMAL: Color("6f8a4b"), FOREST: Color("48683a"), OBSTACLE: Color("7f776c"), FONT: Color("3fa9bd"),
		HAZE: Color("cbc4ae"), SUN: Color("fff2dc"), AMBIENT: Color("c0bfb8"),
	},
	BoardGenerator.Stage.TWIN_SPRINGS: {
		NORMAL: Color("54906c"), FOREST: Color("33684e"), OBSTACLE: Color("6e7888"), FONT: Color("46bcd6"),
		HAZE: Color("abc8da"), SUN: Color("eef6ff"), AMBIENT: Color("b2c6da"),
	},
}


## ステージの色合い（色の名前 -> Color）。知らないステージなら、中央平原の色。
static func of(stage: int) -> Dictionary:
	return LOOKS.get(stage, LOOKS[BoardGenerator.Stage.PLAIN])


## 空・霞・光を parent に足す（タイトルと対戦の設定の場面の背景も、同じ景色にする。backdrop.gd）。
static func build_environment(parent: Node) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = COLOR_HAZE
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8c4d6")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	# 遠くの地面と景色は、空の色の霞に溶かす（盤の外の端が、ぷつりと切れて見えないように）。
	# 盤の中は、いちばん引いても霞まない距離から始める。
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = COLOR_HAZE
	environment.fog_sun_scatter = 0.0
	environment.fog_depth_begin = FOG_BEGIN
	environment.fog_depth_end = FOG_END
	environment.fog_depth_curve = 1.6

	var world := WorldEnvironment.new()
	world.environment = environment
	parent.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	parent.add_child(sun)


## ステージの色合い（of）の霞・空・光を、build_environment で足したものに当てる。
static func apply(parent: Node, look: Dictionary) -> void:
	for node in parent.get_children():
		var world := node as WorldEnvironment
		if world != null:
			world.environment.background_color = look[HAZE]
			world.environment.fog_light_color = look[HAZE]
			world.environment.ambient_light_color = look[AMBIENT]
		var sun := node as DirectionalLight3D
		if sun != null:
			sun.light_color = look[SUN]
