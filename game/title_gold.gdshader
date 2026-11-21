shader_type canvas_item;
// 題字の金。字の上から下へ、明るい金から深い金へ移し、真ん中より少し上に細い照り返しを入れる（彫った金属の字に見せる）。
// 文字の色（COLOR）に掛けるので、縁取りと影は暗いまま残る。色は title_screen.gd が UI の色（ui_palette.gd）から渡す。

uniform vec4 top : source_color = vec4(1.0);
uniform vec4 bottom : source_color = vec4(1.0);
// 字の箱の高さ（px）。
uniform float height = 100.0;
// 照り返しの高さ（0 = 上、1 = 下）と強さ。
uniform float shine_at = 0.42;
uniform float shine = 0.22;

varying float level;

void vertex() {
	level = clamp(VERTEX.y / height, 0.0, 1.0);
}

void fragment() {
	vec4 tint = mix(top, bottom, smoothstep(0.15, 0.95, level));
	float band = 1.0 - smoothstep(0.0, 0.07, abs(level - shine_at));
	COLOR.rgb *= tint.rgb + vec3(band * shine);
}
