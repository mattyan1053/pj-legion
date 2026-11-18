shader_type canvas_item;
// 場面の切り替えの幕（app.gd）。ただの暗転ではなく、夜の藍が斜めに拭き取るように覆い、明けるときは同じ向きへ抜ける。
// 縁はやわらかくにじませ、縁に沿って真鍮の細い光を走らせる。長さは暗転と同じ（待ち時間は増やさない）。

uniform vec4 ink : source_color = vec4(0.05, 0.07, 0.10, 1.0);
uniform vec4 edge : source_color = vec4(0.82, 0.68, 0.38, 1.0);
// 0 = すっかり明けている、1 = すっかり覆っている。
uniform float cover = 0.0;
// 覆う（1）か、明ける（-1）か。明けるときは、覆ったのと同じ側から抜ける。
uniform float direction = 1.0;
// 縁のにじみの幅（画面の斜めの長さに対する割合）。
uniform float softness = 0.22;

void fragment() {
	// 左上から右下へ進む斜めの位置（0〜1）。
	float along = UV.x * 0.78 + UV.y * 0.22;
	// 覆うとき: 縁が左上から右下へ進み、縁の後ろが覆われる。明けるとき: 縁が同じ向きに進み、縁の後ろが明ける。
	float filled;
	if (direction > 0.0) {
		filled = smoothstep(0.0, softness, cover * (1.0 + softness) - along);
	} else {
		filled = smoothstep(0.0, softness, along + softness - (1.0 - cover) * (1.0 + softness));
	}
	float rim = filled * (1.0 - filled) * 4.0;
	COLOR = vec4(mix(ink.rgb, edge.rgb, rim * 0.35), filled);
}
