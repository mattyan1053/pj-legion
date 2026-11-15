extends RefCounted
## ステージごとの色合い（地面の色、霞と空の色、光の色）。盤の形はルール（BoardGenerator）が決め、ここは色だけを決める。
## 素材は替えない（木と岩山の形は同じ）。地面の色と、空気の色（霞・光）で、どのステージかが一目で分かるようにする。
##
## - 中央平原: 明るい若草色。昼の白い光。
## - 迷宮回廊: 乾いたオリーブ色の地面と、暖かい石の色。夕方寄りの、砂ぼこりの霞。
## - 双子結晶: 青みのある緑の地面と、青い石。結晶の泉の、ひんやりした霞。
##
## 本陣の陣営の色、マスの塗り分け、駒、HP の棒の色は、どのステージでも変えない（読み方を変えないため）。

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
