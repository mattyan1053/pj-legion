extends RefCounted
## 対戦の画面の操作の状態（選んでいる駒、見ている駒、対象を選ぶ途中、確かめの途中、押している途中、再生と CPU の番の途中）。
## ノードに依存しない。対戦の場面（battle_screen.gd）が 1 つ持ち、状態はここを通して変える。
##
## 状態を消すときの単位は、ここに 1 つずつ置く（clear_for_new_battle、clear_after_action、select など）。
## 状態を 1 つ足したら、消す単位のどれに入るかを決めて、ここに足す。場面の側に、消す並びを書き写さない。
## 組み合わせの決まり（見ている駒が選んでいる駒と同じなら見るのをやめる、など）は reconcile に置く。

const NO_CELL := Vector2i(-1, -1)

## 押してから離すまでにマウスがこれより動いたら、クリックではなくドラッグ（視点を回す・傾ける）と見る（px）。
## 回す速さ（感度）は OrbitCamera.drag_sensitivity。
const DRAG_THRESHOLD := 8.0

## 対象を選んでいる途中か。その間は、塗るのは対象のマスだけで、クリックは対象を選ぶ（ほかのマスなら、やめる）。
## NONE でも、赤・緑のマスを直接クリックすれば攻撃・回復できる（メニューの「攻撃」「回復」は、相手だけを見せる近道）。
enum Mode { NONE, ATTACK, HEAL, SKILL }

## 戻す（右クリック・Esc）で、次に何をするか（back）。
enum Back {
	NOTHING,  ## 戻すものが無い
	DONE,  ## ここで戻した（確かめ・閲覧・対象を選ぶ途中をやめた）。場面は表示を作り直す
	UNDO_MOVE,  ## 動いたあと。場面が移動の取り消しを行う
	DESELECT,  ## 選択（とマスの情報、ターン終了の確かめ）をやめる。場面が select(0) を通す
}

## 選んでいる駒（行動させる駒）の番号。0 なら選んでいない。
var selected_id := 0
## 見ている（閲覧している）駒の番号。選んでいる駒とは別に持つ。
## 見ている間は、その駒の動ける範囲と脅威範囲を塗り、選択・移動・対象を選ぶ途中はそのまま残す。0 なら見ていない。
var inspected_id := 0
## クリックして情報を出しているマス（駒のいないマス。無ければ NO_CELL）。
var inspected_cell := NO_CELL
var mode := Mode.NONE
## 未行動の駒を残したままターンを終えるかを、もう一度押して確かめている途中か。
var confirming_end := false
## 必殺技を使うかを、もう一度押して確かめている途中か（対象を選ばず、取り消せないので、1 回では使わない）。
var confirming_ult := false
## マウスが乗っているメニューの項目（乗っていなければ空の名前）。その項目の説明を、左下の枠に出す。
## 画面（battle_hud.gd）が知らせるマウスの位置を写すだけなので、消す単位には入れない。
var menu_hover_id := &""

## 左ボタンを押した場所と、押している途中か、そこが駒のいるマスか、押してからドラッグになったか。
var press_position := Vector2.ZERO
var pressing := false
var press_on_unit := false
var dragging := false

## イベントを再生している途中か。この間は、操作を受け付けない。
var busy := false
## CPU の番を進めている途中か（行動と行動の間の待ち時間も含む）。この間は、操作を受け付けない。
var cpu_running := false


# ---- 消す単位 ----


## 新しい対戦を始める: 選択・閲覧・対象を選ぶ途中・確かめ・押している途中を、前の対戦から持ち越さない
## （駒の番号は対戦ごとに 1 から振り直すので、前の対戦の番号を残すと、別の駒を指す）。
func clear_for_new_battle() -> void:
	selected_id = 0
	inspected_id = 0
	inspected_cell = NO_CELL
	mode = Mode.NONE
	confirming_end = false
	confirming_ult = false
	cancel_press()


## 行動をルールに渡した: 閲覧・マスの情報・対象を選ぶ途中・確かめをやめる（盤が変わるので）。選んでいる駒は、再生のあとに決める（settle_after_action）。
func clear_after_action() -> void:
	mode = Mode.NONE
	inspected_id = 0
	inspected_cell = NO_CELL
	confirming_end = false
	confirming_ult = false


## 行動の再生が終わったあとに、選んでいる駒を決める。
## - CPU の番は、選べることを出さない。
## - 進化先を選ぶ駒がいれば（決着していなければ）、選ぶまでその駒を見せる（evolving_id）。
## - 動いたあと（acting_id）は、その駒のまま。続けて攻撃・回復・待機・取り消しを選ぶ。
## - そのほかは選択を外す。ただし、移動の取り消しと必殺技（駒の行動ではない）なら、選んでいた駒はそのまま（keeps_selection）。
func settle_after_action(cpu_turn: bool, evolving_id: int, acting_id: int, keeps_selection: bool) -> void:
	if cpu_turn:
		selected_id = 0
	elif evolving_id != 0:
		selected_id = evolving_id
	elif acting_id != 0:
		selected_id = acting_id
	elif not keeps_selection:
		selected_id = 0


## 駒を選ぶ（0 なら選ぶのをやめる）。閲覧・マスの情報・対象を選ぶ途中・確かめはやめる。選ぶ駒が変わったかを返す。
func select(unit_id: int) -> bool:
	var changed := unit_id != selected_id
	selected_id = unit_id
	inspected_id = 0
	inspected_cell = NO_CELL
	mode = Mode.NONE
	confirming_end = false
	confirming_ult = false
	return changed


## 駒を見る（閲覧）。選んでいる駒、動いたあとの状態、対象を選ぶ途中は、そのまま残す。0 なら見るのをやめる。
func inspect(unit_id: int) -> void:
	inspected_id = unit_id
	confirming_end = false


## 駒のそばのメニューの項目を押した: 必殺技の確かめと閲覧をやめて、選んでいる駒の行動へ戻る。
func focus_selected() -> void:
	confirming_ult = false
	inspected_id = 0


## 必殺技を使うかを確かめ始める（対象を選ぶ途中はやめる）。
func start_confirming_ult() -> void:
	confirming_ult = true
	mode = Mode.NONE


## 戻す（右クリック・Esc）。必殺技の確かめ、閲覧、対象を選ぶ途中の順に、1 つだけやめる。
## そのどれでもなければ、動いたあと（moving）なら移動の取り消し、選択・マスの情報・ターン終了の確かめがあれば選ぶのをやめる。
## 何をするか（Back）を返す。DONE のときは、ここでもうやめている。
func back(moving: bool) -> Back:
	if confirming_ult:
		confirming_ult = false
		return Back.DONE
	if inspected_id != 0:
		inspect(0)  # 見るのをやめて、元の行動の途中へ戻る
		return Back.DONE
	if mode != Mode.NONE:
		mode = Mode.NONE
		return Back.DONE
	if moving:
		return Back.UNDO_MOVE
	if selected_id != 0 or inspected_cell != NO_CELL or confirming_end:
		return Back.DESELECT
	return Back.NOTHING


# ---- 組み合わせの決まり ----


## 表示を作り直す前に、いまの盤では成り立たない組み合わせを外す。引数は、場面がルールに問い合わせた、いまの盤のこと。
## - CPU の番を進めている途中か、必殺技を使えなければ（can_ult）、必殺技の確かめをやめる。
## - 選んでいる駒がいなくなったら（selected_exists）、選択を外す。
## - 対象を選ぶ途中は、選んでいる駒が行動できない・決着した・CPU の番（cpu_turn）・選べる対象が無くなったら、やめる。
## - 駒を選んでいれば、マスの情報は出さない。
## - 見ている駒がいなくなったか、決着したか、見ている駒が選んでいる駒と同じなら、見るのをやめる。
func reconcile(
	selected_exists: bool, selected_can_act: bool, inspected_exists: bool, over: bool, cpu_turn: bool,
	can_ult: bool, can_attack: bool, can_heal: bool, can_skill: bool
) -> void:
	if cpu_running or not can_ult:
		confirming_ult = false
	if not selected_exists:
		selected_id = 0
	if not selected_exists or over or cpu_turn or not selected_can_act:
		mode = Mode.NONE
	elif mode == Mode.SKILL and not can_skill:
		mode = Mode.NONE
	elif mode == Mode.ATTACK and not can_attack:
		mode = Mode.NONE
	elif mode == Mode.HEAL and not can_heal:
		mode = Mode.NONE
	if selected_exists:
		inspected_cell = NO_CELL
	if not inspected_exists or over or inspected_id == selected_id:
		inspected_id = 0


# ---- 押している途中（左ボタン） ----


## 左ボタンを押した。押しただけでは何もしない（離すまでに動かなければクリック、動けばドラッグ。駒の上で押したときは、いつもクリック）。
func press(position: Vector2, on_unit: bool) -> void:
	pressing = true
	dragging = false
	press_position = position
	press_on_unit = on_unit


## 左ボタンを離した。押している途中で、ドラッグにならなかったなら、クリックとして真を返す。
func release() -> bool:
	if not pressing:
		return false
	pressing = false
	var click := not dragging
	dragging = false
	return click


## 押している途中のマウスが position へ動いた。視点を動かす（ドラッグ）なら真を返す。
func drag(position: Vector2) -> bool:
	if press_on_unit:
		return false
	if not dragging and position.distance_to(press_position) > DRAG_THRESHOLD:
		dragging = true
	return dragging


## 押している途中の操作をやめる（メニュー・ログを開いた、ボタンを帯やメニューの上で離した、新しい対戦）。
func cancel_press() -> void:
	pressing = false
	dragging = false
