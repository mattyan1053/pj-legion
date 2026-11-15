shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// マス目。地面の上に重ねる補助の線（地面に刻んだ溝ではない）。
// ふだんはごく薄く、操作しているとき（emphasis）と、マウスの下のマスの周り（cursor）は、はっきり出す。
// 盤の縁（戦う範囲の境目）は、いつも少し濃く出す。

uniform vec2 board_size = vec2(30.0, 30.0);
uniform vec3 line_color : source_color = vec3(1.0, 1.0, 0.9);
uniform float idle_alpha = 0.17;
uniform float active_alpha = 0.46;
uniform float border_alpha = 0.42;
// 線の幅の半分（マス）。
uniform float half_width = 0.014;
uniform float border_half_width = 0.026;
// 0 = ふだん、1 = 操作している。
uniform float emphasis = 0.0;
// マウスの下のマスの中心（x, z）と、出ているか（0 か 1）。
uniform vec3 cursor = vec3(0.0);
// マウスの周りで線を濃くする範囲（マス）。near までは濃く、far で消える。
uniform float cursor_near = 1.2;
uniform float cursor_far = 4.2;

varying vec2 ground;

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

// 線からの距離 away（マス）と、1 ピクセルの幅 pixel（マス）から、線の濃さを出す。
// 遠くで線が 1 ピクセルより細くなったら、ちらつかないよう、そのぶん薄くする。
float coverage(float away, float pixel, float half_line) {
	return clamp((half_line - away) / pixel + 0.5, 0.0, 1.0) * min(1.0, 2.0 * half_line / pixel);
}

void fragment() {
	vec2 pixel = max(fwidth(ground), vec2(0.0001));
	vec2 to_line = abs(fract(ground + 0.5) - 0.5);
	float line = max(coverage(to_line.x, pixel.x, half_width), coverage(to_line.y, pixel.y, half_width));

	vec2 inside = min(ground, board_size - ground);
	// 盤の外には引かない。
	line *= step(-half_width, min(inside.x, inside.y));
	float near = cursor.z * (1.0 - smoothstep(cursor_near, cursor_far, distance(ground, cursor.xy)));
	float alpha = line * mix(idle_alpha, active_alpha, max(emphasis, near));

	float border = 0.0;
	if (inside.y > -border_half_width) {
		border = max(border, coverage(abs(inside.x), pixel.x, border_half_width));
	}
	if (inside.x > -border_half_width) {
		border = max(border, coverage(abs(inside.y), pixel.y, border_half_width));
	}
	alpha = max(alpha, border * border_alpha);

	ALBEDO = line_color;
	ALPHA = alpha;
}
