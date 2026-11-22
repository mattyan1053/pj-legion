extends RefCounted
## 「枠の大きさは中身で変えない」の印（docs/ui-theme.md の「枠の大きさ」）。
## 枠（パネル、窓、札、欄、帯、ボタンの並び）を作ったら、ここで印を付ける。
## 印の付いた枠は、検査（自動の対戦と通しの点検。game/steady_probe.gd）が毎コマ大きさを控え、
## 出ている間に大きさが変わったら（中身を替えたら伸びた、縮んだ）失敗にする。

const GROUP := &"steady_frame"
const META := &"steady_frame"
## 大きさだけを見る（置き場所は、まわりの都合で動いてよい。駒のそばのメニューなど）。
const SIZE := &"size"
## 幅だけを見る（行の数で高さが変わる並び。駒のそばのメニュー、一覧）。
const WIDTH := &"width"
## 大きさと置き場所の両方を見る（画面の決まった所に出る枠）。
const RECT := &"rect"


## frame に印を付ける。what は、検査が落ちたときに出す名前（`sortie.unit_note` のように、画面と枠が分かる英字。画面には出ない）。
static func mark(frame: Control, what: String, kind: StringName = SIZE) -> void:
	frame.add_to_group(GROUP)
	frame.set_meta(META, [what, kind])


static func name_of(frame: Control) -> String:
	return String(frame.get_meta(META)[0])


static func kind_of(frame: Control) -> StringName:
	return frame.get_meta(META)[1]
