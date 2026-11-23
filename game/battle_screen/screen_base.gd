extends Node3D
## 対戦の場面（game/battle_screen.gd）の土台: 読み込み、調整値、状態の変数と、どの役割からも使う小さな道具。
## 役割ごとのファイル（screen_*.gd）は、これを継いで順に積み重なる（battle_screen.gd が最後）。


const Text := preload("res://game/text.gd")
const Palette := preload("res://game/ui_palette.gd")
const OrbitCamera := preload("res://game/orbit_camera.gd")
const UnitView := preload("res://game/unit_view.gd")
const UnitLooks := preload("res://game/unit_looks.gd")
const BoardView := preload("res://game/board_view.gd")
const BattleHud := preload("res://game/battle_hud.gd")
const Names := preload("res://game/names.gd")
const BattleSource := preload("res://game/battle_source.gd")
const MatchSetupPanel := preload("res://game/match_setup_panel.gd")
const Queries := preload("res://game/battle_queries.gd")
const ForecastText := preload("res://game/forecast_text.gd")
const Autoplay := preload("res://game/autoplay.gd")
const ResultSummary := preload("res://game/result_summary.gd")
const PhaseFocus := preload("res://game/phase_focus.gd")
const SystemMenu := preload("res://game/system_menu.gd")
const Settings := preload("res://game/settings.gd")
const AppContext := preload("res://game/app_context.gd")
const BattleLog := preload("res://game/battle_log.gd")
const LogPanel := preload("res://game/log_panel.gd")
const UnitDetail := preload("res://game/unit_detail.gd")
const UnitSheet := preload("res://game/unit_sheet.gd")
const BattleUiState := preload("res://game/battle_ui_state.gd")
const BattleTexts := preload("res://game/battle_texts.gd")
const FormationText := preload("res://game/formation_text.gd")
const FormationLinks := preload("res://game/formation_links.gd")
const BattlePlayback := preload("res://game/battle_playback.gd")
const PanelLayout := preload("res://game/panel_layout.gd")
const BattleEffects := preload("res://game/battle_effects.gd")
const StageLook := preload("res://game/stage_look.gd")
const Run := preload("res://game/run.gd")
const WinText := preload("res://game/win_text.gd")
const BattleCues := preload("res://game/battle_cues.gd")
const BattleTalk := preload("res://game/battle_talk.gd")
const VersusFields := preload("res://game/versus_fields.gd")
const SoundCatalog := preload("res://game/sound_catalog.gd")


## 場面が終わった（scene_flow.gd の行き先の名前: 決着の画面の「対戦設定へ」は &"setup"、「タイトルへ」は &"title"。
## 「次へ」（渡されたものが許したときだけ出る。ストーリー）は Run.NEXT）。
signal finished(outcome: StringName)


const NO_CELL := Vector2i(-1, -1)
const TEAM_COLORS: Array[Color] = [Palette.TEAM_BLUE, Palette.TEAM_RED, Palette.TEAM_NEUTRAL]


const COLOR_MOVE := Color(0.35, 0.65, 1.0, 0.5)
const COLOR_CRUISE := Color(1.0, 0.82, 0.3, 0.4)
const COLOR_PATH := Color(1.0, 1.0, 1.0, 0.75)
const COLOR_TARGET := Color(1.0, 0.2, 0.15, 0.7)
const COLOR_HEAL := Color(0.3, 0.95, 0.45, 0.7)
const COLOR_SKILL := Color(0.55, 0.25, 0.95, 0.7)
const COLOR_SKILL_AREA := Color(1.0, 0.55, 0.9, 0.85)
const COLOR_INSPECT := Color(0.8, 0.93, 1.0, 0.5)
## ターン終了を確かめている間の、まだ行動していない駒の足元。
const COLOR_UNACTED := Color(1.0, 0.85, 0.35, 0.6)
const COLOR_THREAT := Color(0.95, 0.1, 0.2, 0.34)
const COLOR_SELECTED := Color(1.0, 0.9, 0.3, 0.9)
## 見ている（閲覧している）駒の足元の輪。選んでいる駒の黄の輪と見分ける。
const COLOR_INSPECTED := Color(0.85, 0.95, 1.0, 0.95)
## ログの行を選んだときに示す、出来事のあったマスと、関わった駒のいまのマス。
const COLOR_LOG_PLACE := Color(1.0, 0.82, 0.25, 0.75)
const COLOR_LOG_UNIT := Color(0.95, 0.97, 1.0, 0.7)


## 駒のそばのメニューの項目の名前（battle_texts.gd）。
const MENU_ATTACK := BattleTexts.MENU_ATTACK
const MENU_HEAL := BattleTexts.MENU_HEAL
const MENU_SKILL := BattleTexts.MENU_SKILL
const MENU_WAIT := BattleTexts.MENU_WAIT
const MENU_UNDO := BattleTexts.MENU_UNDO
const MENU_BACK := BattleTexts.MENU_BACK
const MENU_WARP := BattleTexts.MENU_WARP


## 対象を選んでいる途中か（battle_ui_state.gd）。
const Mode := BattleUiState.Mode


## CPU の駒が動き出す前に、カメラを寄せて見せる秒数と、1 体の行動が終わってから次の駒までの間。
const CPU_FOCUS_TIME := 0.35
const CPU_PAUSE := 0.45
## 早送り（相手の番の下の帯のボタン）の速さ。設定の「CPU の番の速さ」に、さらに掛ける。
const FAST_FORWARD_SCALE := 4.0


## いまの対戦。再生（battle_playback.gd）にも渡す。
var battle: Battle:
	set(value):
		battle = value
		if _playback != null:
			_playback.battle = value
## フェーズの始めにカメラが寄る駒を決める（phase_focus.gd）。行動のたびに、起きたことを食わせる。
var _phase_focus := PhaseFocus.new()
## いまの対戦の戦績。行動のたびに、起きたことを食わせる（決着の画面に要点を出す）。
var stats: BattleStats
## 対戦のログ（battle_log.gd）。再生（battle_playback.gd）が、再生したイベントを、再生した順に食わせる。
var battle_log: BattleLog:
	set(value):
		battle_log = value
		if _playback != null:
			_playback.battle_log = value
## いまの盤の見た目の名前（stage_look.gd）と、決着の画面の「マップ」に出す名前（戦いの定義の名前）。
var look := StageLook.DEFAULT
var area_name := ""
var map_seed := 0


var _board_view: BoardView
var _formation_links: FormationLinks
var _effects: BattleEffects
var _views := {}  # 駒の番号 -> UnitView
## 名前のある人物の形の付いた駒（駒の番号 -> unit_looks.gd の PERSONS の名前。話の [cast]。start_with で決める）。
var _people := {}
var _hud: BattleHud
var _setup_panel: MatchSetupPanel
var _unit_detail: UnitDetail
var _rig: OrbitCamera
var _selection_ring: MeshInstance3D
var _inspect_ring: MeshInstance3D


## システムメニューに足す項目の名前。
const SYSTEM_MATCH_SETUP := &"match_setup"


## アプリ（app.gd）から渡されるもの。場面を作ってから木に入れる前に入る。
var context: AppContext
## 遊ぶ人ごとの設定（settings.gd。context が持つ）。
var settings: Settings
## ふだんの時間の速さ（Engine.time_scale）。自動の対戦は、検査を短く済ませるために上げる。
## システムメニューを開いている間は 0（止める）、CPU の駒の番は設定の「CPU の番の速さ」を掛ける（_update_time_scale）。
var time_scale_base := 1.0
var _system_menu: SystemMenu
var _log_panel: LogPanel
## CPU の駒の行動を再生している途中か（設定の「CPU の番の速さ」を効かせる）。
var _cpu_fast := false
## 早送りを入れているか（相手の番の下の帯の「早送り」。切り替え。入れたままなら、次の相手の番も早送り）。
var fast_forward := false
## いま再生している行動が、見ているだけの番のものか（行動の前か後のどちらかが見ているだけの番）。
## CPU が番を終える行動は、ルールの上ではもう人の番だが、再生の中身（中立のフェーズ）は見ているだけの番なので、これで見る。
var _watch_playback := false


## 対戦設定を作ってくれるもの（battle_source.gd）。やり直し（F1〜F3、結果のボタン）も、これで始める。
var source: BattleSource
## 相手を CPU が動かすか。偽なら、2 人が交代で操作する。CPU が動かすのは source.cpu_side()。
## 対戦を作るときに、対戦設定（MatchSetup.controllers）から決める。対戦の途中の切り替え（F4）で変わる。
var cpu_opponent := true
## CPU が実行した行動の数。検査用。
var cpu_actions := 0
var _cpu := CpuPlayer.new()
## 自分の番を任されている陣営（おまかせ。任されていなければ -1）と、その番を動かす CPU（相手の CPU とは別に持つ）。
var _auto_side := -1
var _auto_cpu := CpuPlayer.new()
## 操作の状態（選んでいる駒、見ている駒、対象を選ぶ途中、確かめ、押している途中、再生と CPU の番の途中）。battle_ui_state.gd。
var _ui := BattleUiState.new()
## 対戦の途中の会話（battle_cues.gd）と、その札（battle_talk.gd）。台詞は渡すもの（source.talk_cues）が持つ。
var _cues: BattleCues
var _talk: BattleTalk
## 台詞を送られるのを待つ間、クリックを受け止める幕（透明）。
var _talk_catcher: Control
## 敵の全員の脅威範囲（Threat.against）を、盤に重ねて出しているか（下の帯の切り替え）。
var _threat_shown := false
var _hover_cell := NO_CELL
## いまの選択で選べること（_refresh が作り直す）。
var _move_cells := {}  # マス -> 巡航でしか届かないか
var _targets: Array[Unit] = []
var _barrel_targets: Array[Vector2i] = []
var _barricade_targets: Array[Vector2i] = []
var _heal_targets: Array[Unit] = []
var _skill_cells: Array[Vector2i] = []
## 選んでいる駒が、いまのポータルから転移できるなら行き先（Queries.warp_exit）。できなければ NO_CELL。
var _warp := NO_CELL
## 選んでいる駒の移動の範囲にある、転移に使えるポータル（入る -> 出る。Queries.reachable_portals）。
var _portals := {}
## 駒のそばのメニューと、戦闘予測のパネルの置き場所（panel_layout.gd）。
var _layout: PanelLayout
## 検査で、マウスを乗せたことにしているマス（hover）。NO_CELL ならマウスの位置。
var _hover_forced := NO_CELL
## 対戦を始めたことがあるか（起動した直後の設定画面だけ偽。偽の間は、設定画面を閉じて戻る先が無い）。
var _battle_started := false
## 終盤の曲（sound_catalog.gd の CLIMAX_MUSIC）: 対戦の初めの将の番号と、もう替えたか。
var _climax_kings: Array[int] = []
var _climax := false
## カメラが追いかけた駒の番号 -> 回数。検査用。
var camera_follows := {}
## 再生したイベントの数（イベントのスクリプト -> 回数）。検査用。
var played := {}
## イベントの再生（battle_playback.gd）。
var _playback: BattlePlayback
var _painted := {}  # 塗っているマス -> Color（道の表示を重ねる前のもの）


## 毎フレームの終わり（_process の終わり）。再生の途中で、次のフレームまで待つのに使う。
signal frame_passed


## ミニマップを置き、盤の上の駒と見ている範囲を描き直す。
func _place_minimap() -> void:
	if battle == null or not is_inside_tree():
		return
	_hud.place_minimap()
	if _hud.minimap().visible:
		_hud.minimap().refresh(battle, _views, _rig.camera, get_viewport().get_visible_rect().size)


## side の将の姿（渡されたもの（source）が決める。見た目だけ）。中立の陣営は空。
func _king_look(side: int) -> StringName:
	var looks := source.king_looks() if source != null else [] as Array[StringName]
	return looks[side] if side >= 0 and side < looks.size() else &""


## unit の駒の姿（名前のある人物の形が先。無ければ、その陣営の将の姿）。
func _look_of(unit: Unit) -> StringName:
	return _people.get(unit.id, _king_look(unit.side))


## 操作を受け付けない間か（イベントの再生の途中か、CPU の番を進めている途中か、重なる画面（対戦設定画面・システムメニュー・ログ）を開いている間）。
func is_busy() -> bool:
	return _ui.busy or _ui.cpu_running or context.overlays.is_open() or _talk.is_holding()


## 「詳細」で開く駒（見ている駒が先、無ければ選んでいる駒）。
func _detail_unit() -> Unit:
	var unit := inspected_unit()
	return unit if unit != null else selected_unit()


## ミニマップが画面に占める四角（出していなければ大きさ 0）。検査とスクリーンショットの道具用。
func minimap_rect() -> Rect2:
	return _hud.minimap_rect()


## 人が見ているだけの番か（相手が CPU で、CPU の番か、中立のフェーズ）。早送りとスキップが効くのは、この間だけ。
func _watching_other() -> bool:
	if battle == null or battle.is_over():
		return false
	return _watch_playback or (cpu_opponent and battle.phase != _human_side()) or _auto_running()


## いまが、CPU が動かす番か。
func _is_cpu_turn() -> bool:
	if battle.is_over():
		return false
	return (cpu_opponent and battle.phase == source.cpu_side()) or _auto_running()


## おまかせの番を CPU が進めているか。任せた側の駒が進化先を選ぶのを待っている間は、人に選ばせるので止まる
## （選ぶと、続きを CPU が進める）。
func _auto_running() -> bool:
	return battle.phase == _auto_side and battle.evolving_unit() == null


## 番の知らせに出す陣営の名前（CPU が動かすなら、そう書く）。
func _side_name(side: Unit.Side) -> String:
	if Names.story_sides:
		return Names.side(side)
	if cpu_opponent and side == source.cpu_side():
		return Text.t("battle.side_cpu", {"color": Names.side_word(side)})
	return Names.side(side)


## CPU と対戦するときに、人が動かすプレイヤー（相手の反対）。
func _human_side() -> Unit.Side:
	return (1 - source.cpu_side()) as Unit.Side


func selected_unit() -> Unit:
	return battle.unit_by_id(_ui.selected_id)


## 見ている駒（見ていなければ null）。検査用。
func inspected_unit() -> Unit:
	return battle.unit_by_id(_ui.inspected_id) if _ui.inspected_id != 0 else null


## 範囲を表示したままにできる駒か（盤を見ている人のプレイヤーの敵: 相手の駒と中立の駒）。
func _can_pin(unit: Unit) -> bool:
	return unit.side != _viewer_side()


## side の番が来たときにカメラが見る地点。寄る駒（phase_focus.gd。前回最後に動かした駒）のいるところから、少し敵の本陣のほうへ寄せる
## （駒が盤の端にいると、画面の半分が盤の外になるため）。駒がいなければ自分の本陣から。
func _camera_point(side: Unit.Side) -> Vector3:
	var focus := _phase_focus.unit_for(battle, side)
	var from := BoardView.cell_center(focus.cell if focus != null else battle.board.hq_cells[side])
	var toward := BoardView.cell_center(battle.board.hq_cells[1 - side]) - from
	return from + toward.limit_length(4.0)


func _view(unit_id: int) -> UnitView:
	return _views[unit_id]


## 盤を見ている人のプレイヤー。CPU と対戦するときは、いつも人のプレイヤー（CPU の番の間も）。
## 人どうしでは、いまの番のプレイヤー（中立の番では、プレイヤー1）。必殺技のボタンと、敵の全員の脅威範囲が、このプレイヤーのもの。
func _viewer_side() -> Unit.Side:
	if cpu_opponent:
		return _human_side()
	if battle.phase == Unit.Side.NEUTRAL:
		return Unit.Side.PLAYER1
	return battle.phase


## 駒の足元の輪（選んでいる駒、見ている駒の印）。
func _build_ring(color: Color, inner: float, outer: float) -> MeshInstance3D:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = inner
	ring_mesh.outer_radius = outer
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.material_override = material
	ring.scale = Vector3(1.0, 0.15, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.visible = false
	add_child(ring)
	return ring
