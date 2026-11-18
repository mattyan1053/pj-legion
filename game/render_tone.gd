extends RefCounted
## 描画方式による見え方の差を埋める（ノードに依存しない）。Windows の exe は Forward+ で動く（project.godot）ので、Forward+ を基準にする。
## 見た目（光の強さ、色の調子、地面の模様の濃さ、範囲の色の濃さ）は、もとは互換の描画（OpenGL）で見て決めたもの。
## Forward+ でも、その見え方（docs/battle-view.md の「描画方式」）になるように、ここで Forward+ の側を寄せる。互換の描画では何もしない。
##
## - 色の調子: Forward+ は、同じ光でも地面が 2 割ほど暗く、むらと模様（石畳の目など）が薄く、暗い景色ほど沈む。
##   トーンマッピングを ACES にして露出を上げ、環境光を強め、地面の模様を濃くする。
## - 半透明の重ね塗り（範囲の色、マス目の線、斜線）: 互換の描画は sRGB の値のまま混ぜ、Forward+ は線形の光の量で混ぜるので、
##   同じ不透明度でも Forward+ のほうが濃く（明るく）出る。Forward+ では、互換で混ぜたときと同じ見え方になる不透明度に下げる。

## Forward+ のトーンマッピングと露出。
const FORWARD_TONEMAP := Environment.TONE_MAPPER_ACES
const FORWARD_EXPOSURE := 1.3
## Forward+ の環境光（まわりの光）の強さに掛ける数。互換の描画は、日の当たらない面と暗い景色（結晶の森）が明るく出る。
const FORWARD_AMBIENT := 2.0
## 半透明を混ぜ直すときに、下にあるとみなす地面の明るさ（sRGB）の既定。盤の地面のおよその明るさ。
const BLEND_GROUND := 0.5
## Forward+ は、混ぜたあとにトーンマッピングと露出が掛かる（互換は、物ごとに掛けてから混ぜる）ので、明るい重ね塗り（白い移動範囲、マス目）が
## さらに強く出る。白のときに不透明度に掛ける数（色が暗いほど 1 に近づける。橙や赤の範囲は、上の直しだけで互換に近い）。
const FORWARD_WHITE_SCALE := 0.7

## Forward+ の地面の模様（むら、色の寄り、斑、枯れ、石畳の目）の濃さ（ground.gdshader の pattern_gain）。
const FORWARD_PATTERN_GAIN := 1.8


## Forward+ のタイトルの裂けた空（rift_sky.gdshader）の明るさに掛ける数。光を受けない空は、露出を上げたぶん白く出る。
const FORWARD_TITLE_SKY := 0.6


## タイトルの空の明るさに掛ける数（互換なら 1）。
static func title_sky_brightness() -> float:
	return FORWARD_TITLE_SKY if is_forward() else 1.0


## 環境光の強さに掛ける数（互換なら 1）。
static func ambient_scale() -> float:
	return FORWARD_AMBIENT if is_forward() else 1.0


## 地面の模様の濃さ（互換なら 1）。
static func pattern_gain() -> float:
	return FORWARD_PATTERN_GAIN if is_forward() else 1.0


## いまの描画方式が、互換の描画（OpenGL）でないか。
static func is_forward() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"


## Forward+ のとき、互換の描画で不透明度 alpha の白を明るさ BLEND_GROUND の地面に混ぜたのと同じ明るさになる不透明度（互換ならそのまま）。
## 地面が暗いマップ（結晶の森）では、同じ線でも濃く見えるので、地面の明るさ ground（sRGB）を渡す。
## brightness は重ねる色の明るさ（sRGB。白で 1）。
static func overlay_alpha(alpha: float, ground := BLEND_GROUND, brightness := 1.0) -> float:
	if not is_forward():
		return alpha
	var scale := lerpf(1.0, FORWARD_WHITE_SCALE, smoothstep(ground, 1.0, brightness))
	return clampf(linear_blend_alpha(alpha, ground, brightness) * scale, 0.0, 1.0)


## 色 color の不透明度を overlay_alpha で直したもの。
static func overlay_color(color: Color, ground := BLEND_GROUND) -> Color:
	return Color(color, overlay_alpha(color.a, ground, color.get_luminance()))


## sRGB で、明るさ ground_srgb の地面に、明るさ overlay_srgb の色を不透明度 alpha で混ぜた明るさを、
## 線形の光の量で混ぜて出すときの不透明度。地面より明るい色は下がり、暗い色は上がる。地面と同じくらいの明るさの色は、そのまま。
static func linear_blend_alpha(alpha: float, ground_srgb := BLEND_GROUND, overlay_srgb := 1.0) -> float:
	var ground := _to_linear(ground_srgb)
	var overlay := _to_linear(overlay_srgb)
	if absf(overlay - ground) < 0.05:
		return alpha
	var wanted := _to_linear(alpha * overlay_srgb + (1.0 - alpha) * ground_srgb)
	return clampf((wanted - ground) / (overlay - ground), 0.0, 1.0)


static func _to_linear(value: float) -> float:
	return Color(value, value, value).srgb_to_linear().r
