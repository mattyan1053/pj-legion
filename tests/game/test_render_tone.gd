extends "res://tests/base_test.gd"
## 描画方式による見え方の差を埋める決まり（game/render_tone.gd）。

const RenderTone := preload("res://game/render_tone.gd")


## 線形の光の量で混ぜたとき、sRGB で混ぜたのと同じ明るさになる不透明度。
func test_linear_blend_matches_the_srgb_blend() -> void:
	for ground: float in [0.3, 0.5, 0.7]:
		for overlay: float in [0.0, 1.0]:
			if absf(overlay - ground) < 0.2:
				continue
			for alpha: float in [0.1, 0.17, 0.46, 0.9]:
				var fixed := RenderTone.linear_blend_alpha(alpha, ground, overlay)
				var g := Color(ground, ground, ground).srgb_to_linear().r
				var o := Color(overlay, overlay, overlay).srgb_to_linear().r
				var shown := Color(fixed * o + (1.0 - fixed) * g, 0.0, 0.0).linear_to_srgb().r
				var wanted := alpha * overlay + (1.0 - alpha) * ground
				assert_between(shown, wanted - 0.002, wanted + 0.002, "地面 %.1f に明るさ %.1f を %.2f で" % [ground, overlay, alpha])


func test_white_gets_lighter_and_dark_colors_get_stronger() -> void:
	assert_true(RenderTone.linear_blend_alpha(0.3, 0.5, 1.0) < 0.3, "白は、線形で混ぜると濃く出るので下げる")
	assert_true(RenderTone.linear_blend_alpha(0.3, 0.5, 0.1) > 0.3, "暗い色は、線形で混ぜると薄く出るので上げる")
	assert_eq(RenderTone.linear_blend_alpha(0.3, 0.5, 0.52), 0.3, "地面と同じくらいの明るさなら、そのまま")
	assert_eq(RenderTone.linear_blend_alpha(0.0, 0.5, 1.0), 0.0)
	assert_between(RenderTone.linear_blend_alpha(1.0, 0.5, 1.0), 0.9999, 1.0)
