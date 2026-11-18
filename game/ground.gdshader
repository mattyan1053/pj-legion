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
uniform float outside_shade = 0.8;
// 流れる雲の影の濃さ（0 = 無し）。
uniform float cloud_shade = 0.1;
// 石畳の濃さ（0 = 無し。マップの見た目の PAVING）と、ところどころ枯れた色に寄せる濃さ（DRY）。
uniform float paving = 0.0;
uniform float dry = 0.45;
// 模様（むら、色の寄り、斑、枯れ、石畳の目）の濃さ。描画方式で模様の出方が違うので、そろえるために掛ける（render_tone.gd）。
uniform float pattern_gain = 1.0;

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
	color *= 1.0 + (0.86 + 0.22 * patches + 0.10 * (grain - 0.5) - 1.0) * pattern_gain;
	// 色の寄り: 大きなむらで、日なたの黄みと、日かげの青みへ少し振る。
	float drift = texture(noise_map, ground * 0.017 + vec2(0.83, 0.29)).r;
	color *= 1.0 + (mix(vec3(0.96, 0.99, 1.05), vec3(1.04, 1.01, 0.94), smoothstep(0.3, 0.7, drift)) - 1.0) * pattern_gain;
	// 細かい斑（草むらや小石）。近くで見たときの手触り。
	float fleck = texture(noise_map, ground * 2.7 + vec2(0.19, 0.44)).r;
	color *= 1.0 + 0.09 * pattern_gain * (smoothstep(0.55, 0.75, fleck) - smoothstep(0.45, 0.25, fleck));
	// 流れる雲の影（ごく薄く、ゆっくり）。
	float cloud = texture(noise_map, ground * 0.012 + vec2(TIME * 0.004, TIME * 0.0015)).r;
	color *= 1.0 - cloud_shade * smoothstep(0.45, 0.75, cloud);
	// ところどころ、枯れた色に寄せる。
	float dried = texture(noise_map, ground * 0.057 + vec2(0.61, 0.17)).r;
	color = mix(color, color * vec3(1.06, 1.0, 0.8), min(1.0, smoothstep(0.5, 0.8, dried) * dry * pattern_gain));

	// 石畳。1 マスに 2 × 2 枚、段ごとに半枚ずらした敷石。目地を暗く、石ごとに明るさを少し変える。
	// ところどころ土に埋もれて（大きいむらの暗いところ）、敷石が途切れる。
	if (paving > 0.0) {
		vec2 stone_at = ground * 2.0;
		stone_at.x += 0.5 * mod(floor(stone_at.y), 2.0);
		vec2 inside = fract(stone_at);
		vec2 edge = min(inside, 1.0 - inside);
		float joint = 1.0 - smoothstep(0.03, 0.09, min(edge.x, edge.y));
		float stone = texture(noise_map, floor(stone_at) * 0.137).r;
		float buried = smoothstep(0.42, 0.3, patches);
		float paved = paving * (1.0 - buried);
		color *= mix(1.0, 1.0 + ((0.9 + 0.2 * stone) * (1.0 - 0.32 * joint) - 1.0) * pattern_gain, paved);
	}

	// 盤の外は、少し暗く、色を抜く（戦う範囲が、光の当たった舞台に見える）。境目のすぐ外には、細い影を落とす。
	vec2 beyond = max(max(-at, at - board_size), vec2(0.0));
	float out_there = length(beyond);
	float outside = smoothstep(0.0, 1.6, out_there);
	color = mix(color, vec3(dot(color, vec3(0.3, 0.59, 0.11))), 0.22 * outside);
	color *= mix(1.0, outside_shade, outside);
	color *= 1.0 - 0.16 * smoothstep(0.0, 0.08, out_there) * smoothstep(0.7, 0.1, out_there);

	ALBEDO = color;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
