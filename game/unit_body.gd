extends Node3D
## 駒の体（足元の印と HP の棒を除いた、駒そのものの形と動き）。駒の見た目の組（unit_looks.gd）が作り、
## 駒の見た目（unit_view.gd）が子に持つ。組ごとの体は、これを継いで動きを書き換える。
##
## ここに書いた動きは、動きを持たない体（中立のコアなど）のための代わり: 攻撃はその場で跳ね、被弾は縮んで戻る。
## 跳ねる・縮むのは駒の見た目ごと（足元の円盤も一緒に）。

## 駒の見た目（unit_view.gd）。代わりの動きは、これを動かす。
var view: Node3D
## 体の高さ（頭の上まで）。将の冠をこの高さに置き、画面に占める四角もこれで出す。
var body_height := 1.3


## 立ち姿（くり返す）。倒れている途中なら呼ばれない。
func play_idle() -> void:
	pass


## 走る（くり返す）。
func play_run() -> void:
	pass


## 話し始めの小さな身振り（会話の場面）。終われば立ち姿に戻る。
func play_gesture() -> void:
	pass


## 攻撃の動き。当たる瞬間までの秒数を返す。
func play_attack() -> float:
	var tween := view.create_tween()
	tween.tween_property(view, "position:y", 0.35, 0.12)
	tween.tween_property(view, "position:y", 0.0, 0.12)
	return 0.2


func play_hit() -> void:
	var tween := view.create_tween()
	tween.tween_property(view, "scale", Vector3.ONE * 0.8, 0.08)
	tween.tween_property(view, "scale", Vector3.ONE, 0.12)


## 倒れる動きを始める。駒の見た目が縮んで消えるまでに待つ秒数を返す（倒れる動きが無ければ 0）。
func play_death() -> float:
	return 0.0


## 全体の明るさ（1 = そのまま。行動済みの駒は暗くする）。
func set_shade(_shade: float) -> void:
	pass
