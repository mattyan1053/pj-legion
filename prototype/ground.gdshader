shader_type spatial;
// 地面。盤の中も外も、1 枚の板に地形の色を塗る（マスごとの板は並べない）。
// 地形の色は、マスごとの色を入れた小さい地図（terrain_map）から取り、境目をノイズで揺らして、マスの形に切れないようにする。

// マスごとの色。1 マス = map_scale ピクセル、周りに map_pad マスぶんの平地が付いている。
uniform sampler2D terrain_map : source_color, filter_linear, repeat_disable;
// つなぎ目の無い、白黒のノイズ。
uniform sampler2D noise_map : filter_linear_mipmap, repeat_enable;
uniform vec2 board_size = vec2(30.0, 30.0);
uniform float map_pad = 2.0;
// 地形の境目を揺らす幅（マス）。
uniform float warp = 0.22;
// 盤の外の地面の明るさ（中を 1 として）。戦う範囲の境目が、さりげなく分かるようにする。
uniform float outside_shade = 0.84;

varying vec2 ground;

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 wobble = vec2(
		texture(noise_map, ground * 0.23).r,
		texture(noise_map, ground * 0.23 + vec2(0.37, 0.71)).r
	) - 0.5;
	vec2 at = ground + wobble * 2.0 * warp;
	vec3 color = texture(terrain_map, (at + map_pad) / (board_size + 2.0 * map_pad)).rgb;

	// むら（大きいものと細かいもの）。べた塗りに見えないように。
	float patches = texture(noise_map, ground * 0.031 + vec2(0.11, 0.53)).r;
	float grain = texture(noise_map, ground * 0.9).r;
	color *= 0.86 + 0.22 * patches + 0.10 * (grain - 0.5);
	// ところどころ、枯れた色に寄せる。
	float dry = texture(noise_map, ground * 0.057 + vec2(0.61, 0.17)).r;
	color = mix(color, color * vec3(1.06, 1.0, 0.8), smoothstep(0.5, 0.8, dry) * 0.45);

	vec2 beyond = max(max(-at, at - board_size), vec2(0.0));
	color *= mix(1.0, outside_shade, smoothstep(0.0, 0.9, length(beyond)));

	ALBEDO = color;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
