shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, shadows_disabled;
// 裂けた空（タイトルの背景。title_backdrop.gd）。カメラを中心にした大きな球の内側に描く。絵は使わず、ここで全部を描く。
// - 天頂は夜の藍、地平は霞の色（horizon。景色の霞と同じ色にして、地面とつなぐ）。
// - 縫い目（裂け目）: -Z の向きの空を、地平から天頂の手前まで縦に走る。芯は結晶の白い光、まわりに光のにじみ。
//   裂け目をまたぐ短い線（縫い糸）を等間隔に置く。
// - 縫い目の左と右で、空の色が違う（left_tint は機械の国ベルク連邦の煙る琥珀、right_tint は魔法の国リュエル騎士領の菫）。
// - 星と、地平の近くのたなびく雲。

uniform vec3 zenith : source_color = vec3(0.03, 0.04, 0.10);
uniform vec3 horizon : source_color = vec3(0.45, 0.42, 0.62);
uniform vec3 left_tint : source_color = vec3(0.80, 0.50, 0.28);
uniform vec3 right_tint : source_color = vec3(0.50, 0.36, 0.86);
uniform vec3 seam_core : source_color = vec3(0.92, 1.0, 1.0);
uniform vec3 seam_glow : source_color = vec3(0.37, 0.88, 0.96);
uniform vec3 stitch : source_color = vec3(1.0, 0.84, 0.42);
// 光の脈の速さと、全体の明るさ（入ったときに 0 から 1 へ）。
uniform float pulse_speed = 0.6;
uniform float reveal = 1.0;

varying vec3 dir;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += amp * noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		amp *= 0.5;
	}
	return sum;
}

// 高さ e（ラジアン）での、縫い目の横の位置（ラジアン）。ぎざぎざに走る。
float seam_at(float e) {
	return 0.035 * sin(e * 7.0 + 0.6) + 0.07 * (noise(vec2(e * 9.0, 3.7)) - 0.5) + 0.03 * (noise(vec2(e * 31.0, 8.1)) - 0.5) + 0.10 * (e - 0.35);
}

void vertex() {
	dir = VERTEX;
}

void fragment() {
	vec3 d = normalize(dir);
	float e = asin(clamp(d.y, -1.0, 1.0));
	float a = atan(d.x, -d.z);
	float up = clamp(e / 1.35, 0.0, 1.0);

	// 縫い目からの横の距離（左が負）。
	float across = (a - seam_at(max(e, 0.0))) * cos(e);
	float dist = abs(across);
	float taper = smoothstep(0.0, 0.16, e) * smoothstep(0.92, 0.5, e);
	float pulse = 0.88 + 0.12 * sin(TIME * pulse_speed + e * 5.0);

	// 空の地: 天頂の藍から地平の霞へ。左と右で色を寄せる（縫い目の近くと、地平の近くほど強い）。
	vec3 side = mix(left_tint, right_tint, smoothstep(-0.5, 0.5, across));
	float low = pow(1.0 - up, 3.0);
	vec3 color = mix(zenith, mix(zenith, side, 0.42), pow(1.0 - up, 1.6));
	color = mix(color, side * 0.8, low * 0.55 * exp(-dist * 0.9));
	color = mix(color, horizon, smoothstep(0.16, 0.0, e));

	// 星（上のほうだけ。縫い目の光の近くでは見えない）。
	vec2 star_at = vec2(a * cos(e), e) * 70.0;
	vec2 cell = floor(star_at);
	float star_seed = hash(cell);
	vec2 star_offset = vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5;
	float star = smoothstep(0.09, 0.0, length(fract(star_at) - 0.5 - star_offset * 0.7)) * step(0.86, star_seed);
	star *= 0.55 + 0.45 * sin(TIME * (0.8 + star_seed * 2.0) + star_seed * 40.0);
	color += vec3(0.9, 0.92, 1.0) * star * smoothstep(0.22, 0.6, e) * (1.0 - exp(-dist * 4.0)) * 0.8;

	// たなびく雲（地平の近く）。縫い目の光と、左右の色を受ける。
	float cloud = fbm(vec2(a * 2.2 + TIME * 0.004, e * 13.0));
	float band = smoothstep(0.0, 0.1, e) * smoothstep(0.62, 0.12, e);
	float cover = smoothstep(0.46, 0.74, cloud) * band;
	vec3 cloud_color = mix(zenith * 1.6, side, 0.5) + seam_glow * 0.55 * exp(-dist * 3.0);
	color = mix(color, cloud_color, cover * 0.6);

	// 縫い目: 広いにじみ、近いにじみ、芯。
	float width = 0.011 * taper * (0.75 + 0.5 * noise(vec2(e * 23.0, 1.3)));
	float core = smoothstep(width, width * 0.35, dist) * step(0.0005, taper);
	color += seam_glow * exp(-dist * 4.5) * 0.30 * taper * pulse * reveal;
	color += seam_glow * exp(-dist * 22.0) * 0.75 * taper * pulse * reveal;
	color = mix(color, seam_core, core * reveal);

	// 縫い糸: 裂け目をまたぐ短い線。
	float step_e = 0.062;
	float nearest = (floor(e / step_e) + 0.5) * step_e;
	float slant = (hash(vec2(nearest * 91.0, 2.0)) - 0.5) * 0.5;
	float tick_dist = abs(e - nearest - across * slant);
	float reach = 0.030 + 0.016 * hash(vec2(nearest * 57.0, 5.0));
	float tick = smoothstep(0.0020, 0.0008, tick_dist) * smoothstep(reach, reach * 0.8, dist) * taper;
	color = mix(color, stitch, tick * 0.6 * reveal);

	ALBEDO = color;
}
