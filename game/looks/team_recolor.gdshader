// 素材の絵のうち、決まった色合い（hue_center のまわり）の所を陣営の色に塗り替える（docs/battle-view.md の「駒の色」）。
// 絵が 1 枚で面を分けられない素材（糸蜘蛛・殻蟹・糸茸）の体に、陣営の色を出すため。ほかの所は tint を掛けた素材の色のまま。
// 明るさは素材の絵の明るさを ref_value で割ってそろえる（絵の陰影を残す）。shade は行動済みの暗さ。
shader_type spatial;

uniform sampler2D body_texture : source_color, filter_linear_mipmap;
uniform vec3 team_color : source_color = vec3(1.0);
uniform vec3 tint : source_color = vec3(1.0);
uniform float shade = 1.0;
// 塗り替える色合い（0〜1）と、その幅。彩度が min_saturation より低い所（白・黒・灰）は塗り替えない。
uniform float hue_center = 0.0;
uniform float hue_width = 0.06;
uniform float min_saturation = 0.25;
// 塗り替える所の、素材の絵のふつうの明るさ（0〜1）。
uniform float ref_value = 0.3;

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void fragment() {
	vec3 linear_color = texture(body_texture, UV).rgb;
	// 色合いと彩度は、絵の見た目の色（sRGB）で測る。
	vec3 hsv = rgb_to_hsv(pow(linear_color, vec3(1.0 / 2.2)));
	float apart = abs(fract(hsv.x - hue_center + 0.5) - 0.5);
	float weight = (1.0 - smoothstep(hue_width * 0.6, hue_width, apart))
		* smoothstep(min_saturation * 0.6, min_saturation, hsv.y);
	vec3 team = team_color * clamp(hsv.z / ref_value, 0.35, 1.25);
	ALBEDO = mix(linear_color * tint, team, weight) * shade;
	ROUGHNESS = 0.8;
}
