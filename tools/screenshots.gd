extends Node
## ゲームの決まった場面を画像に撮る（PR に貼るため）。`-- --shots <場面,…|all> --out <ディレクトリ>` を付けて起動すると、
## アプリ（app.gd）が、タイトル → 対戦設定 → 対戦 と人と同じ道で対戦に入ったところで、このノードを足す。
## 撮り終えたら終わる。使い方は docs/screenshots.md。
## 対戦の場面は対戦の画面（battle_screen.gd）で撮り、タイトルと対戦設定の場面は、アプリをその場面へ切り替えて撮る。
##
## 場面はどれも、種を決めた対戦（MatchSetup）を CPU どうしで進めて作る。人の操作と同じ入口で駒を選ぶので、
## 毎回同じ絵になる。場面の条件が来なければ、種を替えて作り直す（MORE_SEEDS まで）。それでも作れない場面は飛ばして、
## 最後にまとめて失敗を報告する。場面を足すときは、SCENES に名前と説明を足し、同じ名前の _scene_<名前>() を書く
## （その場面まで状態を作るだけ。撮るのはこのノードがやる）。

const UnitLooks := preload("res://game/unit_looks.gd")
const SceneFlow := preload("res://game/scene_flow.gd")
const Queries := preload("res://game/battle_queries.gd")
const MatchChoice := preload("res://game/match_choice.gd")
const BattleLog := preload("res://game/battle_log.gd")
const OrbitCamera := preload("res://game/orbit_camera.gd")
const BoardView := preload("res://game/board_view.gd")
const Names := preload("res://game/names.gd")
const Text := preload("res://game/text.gd")
const ResultSummary := preload("res://game/result_summary.gd")
const StageLook := preload("res://game/stage_look.gd")
const VersusFields := preload("res://game/versus_fields.gd")
const Maps := preload("res://game/maps.gd")

## 場面の名前 -> 説明（撮る順）。
## 景色の場面（SCENES に並べない。マップと見た目の組み合わせを、名前で作る）:
##   scape.<マップ>.<構図> か scape.<マップ>.<見た目>.<構図>
## マップは game/maps/ の id か、生成のマップの鍵（versus_fields.gd）。見た目は stage_look.gd の名前（書かなければ、マップの見た目）。
const SCAPE := "scape."
const SCAPE_VIEWS := ["wide", "side", "close", "out", "range", "paint"]
const SCAPE_USAGE := "scape.<マップ>.<構図> か scape.<マップ>.<見た目>.<構図>。構図: wide, side, close, out, range"

const SCENES := {
	"title": "タイトルの場面（起動した直後）",
	"title_menu": "タイトルで Esc を押して開いたシステムメニュー",
	"map_select": "マップ選択の場面（タイトルの「対戦」のあと。生成のマップと手で作ったマップの 2 段のカード）",
	"map_hover": "マップ選択で、迷宮回廊のカードにマウスを乗せて、説明が出ている",
	"map_hover_pass": "マップ選択で、大岩の峠のカードにマウスを乗せたところ（背景の景色が、雪の峠に替わる）",
	"map_hover_twin": "マップ選択で、双子結晶のカードにマウスを乗せたところ（背景の景色が、結晶の森に替わる）",
	"setup_ridge": "尾根の小道を選んだ対戦設定（背景が、尾根の小道の景色）",
	"versus_hand_start": "対戦モードの、手で作ったマップ（一覧の最初のもの。画面に出していないものでも）での対戦の始め",
	"versus_hand_last_start": "対戦モードの、手で作ったマップ（一覧の最後のもの。いちばん新しく足したもの）での対戦の始め",
	"versus_hand_result": "対戦モードの、手で作ったマップで CPU に勝ったときのリザルト（「新しいマップ」は生成のマップだけ）",
	"setup": "対戦設定の場面（マップ選択のあと）",
	"setup_again": "対戦の途中で開いた、対戦設定画面（閉じて戻れる）",
	"setup_confirm": "対戦の途中で開いた対戦設定画面で「マップを選び直す」を 1 回押し、確かめている",
	"setup_deck": "対戦設定で、取っておいた部隊を選ぶところ（選択肢を開いた）",
	"setup_preview": "対戦設定で、CPU の部隊の「編成を確認」を開いたところ",
	"setup_unit_detail": "対戦設定の「編成確認」（CPU の部隊）で、駒の札を押して詳しい説明を開いたところ",
	"setup_placement": "対戦設定の「初期位置」の窓（中央平原の代表の形）で、駒を 1 体動かし、もう 1 体を選んでいるところ",
	"setup_random_second": "双子結晶（本陣が対角）で、初期位置の最初の駒を盤の端の側へ動かし、手番ランダムで後手を引いた対戦の始め（端の側の駒は、後手の側でも端の側。左右も返す）",
	"setup_random": "対戦設定で、手番を「ランダム」にしたところ（行の見出しは「あなた」「CPU」）",
	"setup_cpu_deck": "対戦設定で、CPU の行の部隊の選択肢を開いた（CPU の編成・ランダム編成・取っておいた部隊）",
	"setup_cpu_random": "CPU の部隊を「ランダム編成」にして始めた対戦の途中で、対戦設定の「編成確認」を開いた（いまの対戦で組んだ部隊）",
	"deck_list": "部隊編成: 取っておいた部隊の一覧（出せない部隊も理由つきで並ぶ）",
	"deck_delete": "部隊編成: 部隊を消す前の確かめ",
	"deck_rename": "部隊編成: 部隊の名前を入れる窓",
	"deck_none": "部隊編成: 部隊がひとつも無い一覧（「編成なし」）",
	"deck_army": "部隊編成: 「新しい部隊」で、まず軍を選ぶ",
	"deck_empty": "部隊編成: 軍を選んで組み始めた、空の部隊",
	"deck_built": "部隊編成: 組んだ部隊（雇える駒にマウスを乗せて、中身を読んでいる）",
	"deck_equip": "部隊編成: 部隊の駒を選んで、装備を持たせている",
	"deck_over": "部隊編成: 予算を超えて、取っておけない",
	"system_menu": "対戦の途中で開いたシステムメニュー（Esc か右上のボタン）",
	"system_quit": "システムメニューで「ゲームを終える」を押して、確かめている",
	"window_close": "対戦の途中でウィンドウの × を押して、何が残るかを確かめている（対戦モード）",
	"settings": "システムメニューから開いたオプションの画面（感度を変えたところ）",
	"settings_screen": "オプションの画面を下まで送って、区分「画面」（全画面をオンにしたところ）を見せる",
	"menu_note": "メニューの項目にマウスを乗せて、説明が出ている",
	"start": "対戦の始め（ターン 1、何も選んでいない。カメラは味方の真ん中の駒）",
	"phase_camera": "相手の番のあとの自分の番の始め（カメラは、前の自分の番で最後に動かした駒に寄る。白い輪で示す）",
	"pitch_low": "ドラッグで見下ろす角度をいちばん浅くした（下限）",
	"pitch_high": "ドラッグで見下ろす角度をいちばん深くした（上限。ほぼ真上）",
	"move": "自分の駒を選んで、移動範囲と、駒のそばのメニューが出ている",
	"cell": "駒のいないマスをクリックして、マスの情報が出ている",
	"menu_moved": "動いたあとのメニュー（攻撃・待機・移動を取り消す）と、攻撃できる相手",
	"menu_attack": "メニューの「攻撃」を押して、相手を選んでいる",
	"menu_crowd": "駒が固まっているところで出したメニュー",
	"menu_edge": "盤の端・画面の隅にいる駒のメニュー",
	"threat": "相手の駒をクリックして見ている（脅威範囲が出ている）",
	"inspect_moved": "自分の駒を動かしたあと（メニューが出たまま）に、相手の駒を見ている",
	"threat_all": "自分の駒を選んで、敵の全員の脅威範囲（赤い斜線）を重ねている",
	"threat_pin_switch": "相手の駒をクリックして見ている。左下の枠のいちばん下に「範囲を表示したまま」のスイッチ（入れたところ）",
	"threat_pinned": "相手の駒 2 体の範囲を表示したまま（橙の枠）、敵の全員の脅威範囲（赤い斜線）も出している",
	"threat_mix_plain": "敵の全員の脅威範囲（斜線）を出したまま、相手の駒を見ている（その駒の範囲の赤い塗り。中央平原）",
	"threat_mix_labyrinth": "同じく、迷宮回廊（石畳）で",
	"threat_mix_twin_springs": "同じく、双子結晶（結晶の森）で",
	"skill": "スキルの対象を選んでいる",
	"forecast_attack": "動いたあと、攻撃の相手にマウスを乗せて、戦闘予測のパネルが出ている",
	"forecast_defeat": "倒せる相手にマウスを乗せている（予測のパネルに「倒せる！」）",
	"forecast_skill": "範囲のスキルの対象のマスにマウスを乗せている（巻き込む駒が並ぶ）",
	"forecast_heal": "回復役で、回復できる味方にマウスを乗せている",
	"forecast_small": "9×5 の小さな盤で、動いたあとメニューの「攻撃」を押し、隣の相手にマウスを乗せている（縮んだメニューと予測のパネルが重ならない）",
	"battle_unit_detail": "対戦の途中で、傷ついた駒をクリックして見て、情報の枠の「詳細」でステータスの窓を開いたところ（いまの HP、経験値、スキルの残り）",
	"deck_unit_detail": "部隊編成: 持ち物を持たせた駒の札の「詳細」で、ステータスの窓を開いたところ（持ち物での増減が色と矢印で出る）",
	"info_status": "必殺技のあとの駒の情報（所属、状態と残りの期間、装備、スキル）",
	"ult": "必殺技のゲージが READY で、使うかを確かめている",
	"end_confirm": "未行動の駒を残してターン終了を 1 回押し、確かめている（未行動の駒の足元が光る）",
	"mid_boss": "中ボスを倒して、上の帯に聖遺物が出ている",
	"result_headline": "リザルト 1: 勝敗の見出しが中央に出たところ（人どうしは勝った側の名前）",
	"result_stats": "リザルト 2: 見出しが上へ退き、戦績が 1 行ずつ出ているところ",
	"result_mvp": "リザルト 3: MVP が拡大しながら出たところ",
	"result": "リザルト 4: 出そろって、行き先のボタンと入力の案内が出たところ",
	"result_detail": "リザルトで「詳しい戦績（両軍）」を開いたところ",
	"result_victory": "CPU に勝ったときのリザルト（VICTORY）",
	"result_defeat": "CPU に負けたときのリザルト（DEFEAT）",
	"auto_confirm": "自分の番の「おまかせ」を 1 回押して、確かめている（もう一度押すと、残りの駒を CPU が動かしてターンを終える）",
	"cpu_watch": "相手（CPU）の番の途中。下の帯に「早送り」「スキップ」が出ている（必殺技のボタンの代わり）",
	"log_closed": "相手（CPU）の番のあと、ログを閉じている（上の帯の「ログ」のボタン）",
	"log_open": "相手（CPU）の番のあとに、ログを開いた",
	"log_chosen": "ログの行（相手の攻撃）を押して、その場所と駒を盤の上で示している",
	"log_long": "終盤のログ（長いログ。少しさかのぼったところ）",
	"wide": "いちばん引いて、低い角度で、盤の全体とその向こうを見ている",
	"board_edge": "盤の角と、その外側（低い角度で、盤の外へ向いている）",
	"rotated": "カメラを斜めに回して、低い角度で見ている",
	"hit_slam": "前衛の攻撃が当たった瞬間（相手の足元から衝撃の輪が広がる）",
	"hit_slash": "奇襲の攻撃が当たった瞬間（斜めの白い弧）",
	"hit_shot": "スナイパーの射撃が当たった瞬間（光の弾と、散る火花）",
	"hit_magic": "魔法の攻撃が飛んでいるところ（光る球）",
	"wait_sign": "駒が待機した瞬間（足元の輪が縮み、「待機」が出て消える）",
	"skill_fireball": "ファイアボールが飛んで、当たったところ（スキルの色の輪と、炎の球）",
	"skill_barricade": "戦術バリケード（盾の色の光の柱）",
	"skill_smoke": "スモークグレネード（灰色の煙の塊）",
	"skill_saint": "セイントプレイス（金の光の柱）",
	"skill_shield": "ディバインシールド（駒を包む水色の泡）",
	"skill_aim": "精密照準（相手に縮む赤い照準）",
	"skill_shadow": "シャドウステップ（紫の煙と、消える駒）",
	"skill_adrenaline": "アドレナリン注射（立ち昇る黄緑の光）",
	"ult_assault": "総員突撃の発動の瞬間（画面のフラッシュと、必殺技の名前）",
	"ult_eruption": "魔力解放の効果（全員に同時に立つ光の柱と知らせ）",
	"spring": "寄って見た回復の泉（水面に広がる波紋。迷宮回廊）",
	"portal": "寄って見たポータル（渦を巻いて昇る光の粒と、脈打つ面。双子結晶）",
	"tactic": "作戦（試しの決まり）の手札のボタン。1 枚目を 1 回押して、確かめている（中央平原）",
	"setup_tactics": "対戦設定で、試しの決まりの「作戦」を入にして、札を選んだところ（選んだ札の効果が、決まりの行の右に出る）",
	"tactic_march": "作戦の強行軍を使った直後（広がった移動の範囲を塗り、駒ごとに「移動 +2」。手札の上に使った札の効果。中央平原）",
	"trial_notice": "試しの決まりを全部入にした対戦の始め（決まりの知らせ。中央平原）",
	"battery_cell": "砲台（試しの決まり）のマスをクリックして、説明が出ている（中央平原）",
	"battery": "砲台に乗った後衛を選んだところ（射程が伸びている。中央平原）",
	"setup_battery": "対戦設定で、試しの決まりの「砲台」を「あり」にしたところ",
	"stronghold_cell": "拠点（試しの決まり）のマスをクリックして、説明が出ている（中央平原）",
	"stronghold_hover": "拠点（試しの決まり）のマスにマウスを乗せて、下の帯にマスの説明が出ている（長い説明が 2 行に折り返され、切れない）",
	"stronghold": "拠点に駒が乗り、どちらかがあと 1 回の確保で勝つところ（勝ち方の札と確保の数。迷宮回廊）",
	"setup_stronghold": "対戦設定で、試しの決まりの「拠点」を「あり」にしたところ",
	"portal_cell": "ポータルのマスをクリックして、行き先と転送の説明が出ている（双子結晶）",
	"portal_range": "ポータルへ届く駒を選んで、範囲の中のポータルと、その対の出るポータルが同じ色で塗られている（範囲は転移の先まで広げない。双子結晶）",
	"portal_menu": "ポータルのマスへ動いて、メニューに「転移」が出ている（行き先のポータルが塗られている。双子結晶）",
	"portal_warped": "「転移」で対のポータルへ移り、残りの移動力で届くマスが塗られている（双子結晶）",
	"marks": "寄って見た、駒の足元の印（行動済み、HP の棒）と、移動範囲",
	"minimap_pointed": "ミニマップで相手の本陣のあたりを押して、視点がそこへ移った（右上の白い枠が見ている範囲）",
	"minimap_hidden": "設定でミニマップを隠した（右上に何も出ない）",
	"stage_labyrinth": "迷宮回廊の全景",
	"stage_twin_springs": "双子結晶の全景",
	"look_plain_start": "中央平原の対戦の始め（マップの見た目を比べる 3 枚の 1 つ目）",
	"look_plain_wide": "中央平原を、いちばん引いて低い角度で見ている（盤の外の景色）",
	"look_plain_close": "中央平原の盤の真ん中に寄って見ている（障害物・森・平地の見分け）",
	"look_labyrinth_start": "迷宮回廊の対戦の始め",
	"look_labyrinth_wide": "迷宮回廊を、いちばん引いて低い角度で見ている",
	"look_labyrinth_close": "迷宮回廊の盤の真ん中に寄って見ている",
	"look_twin_springs_start": "双子結晶の対戦の始め",
	"look_twin_springs_wide": "双子結晶を、いちばん引いて低い角度で見ている",
	"look_twin_springs_close": "双子結晶の盤の真ん中に寄って見ている",
	"look_boulder_crag": "大岩の峠（草原の見た目）の真ん中の大岩を、斜めの中くらいの距離から見ている（かたまりが 1 つの岩山に見えるか）",
	"look_twin_springs_crag": "双子結晶の真ん中の大きな岩山を、斜めの中くらいの距離から見ている（かたまりが 1 つの岩山に見えるか）",
	"look_twin_springs_crag_low": "双子結晶の真ん中の岩山を、低い角度で、手前の駒ごしに見ている（岩山が駒とマスを隠しすぎないか）",
	"story_slots": "ストーリー: タイトルの「ストーリー」のあとの、セーブデータ選択（1 番と 2 番に進み具合、3 番は空き）",
	"story_slots_copy": "ストーリー: セーブデータ選択で、1 番のコピー先を選んでいるところ",
	"story_slots_delete": "ストーリー: セーブデータ選択で、2 番の削除を確かめているところ",
	"story_campaigns": "ストーリー: タイトルの「ストーリー」のあとの、物語を選ぶ場面（MILITARY の物語と FANTASY の物語が並ぶ）",
	"story_campaigns_berg": "ストーリー: 物語を選ぶ場面で、MILITARY の物語のカードを選んだところ（背景がその物語の景色）",
	"story_campaigns_ruel": "ストーリー: 物語を選ぶ場面で、FANTASY の物語のカードを選んだところ（背景がその物語の景色）",
	"story_slots_fantasy": "ストーリー: セーブデータ選択で、FANTASY の物語のデータ（2 番）を選んだところ（背景がその物語の景色）",
	"story_fantasy_list": "ストーリー: FANTASY の物語を選んだあとの話の一覧（頭の演習。最初の話だけ選べる）",
	"story_fantasy_sortie": "ストーリー: FANTASY の物語の演習（第 2 話「火球」）の出撃準備（この話で覚えること、決まっている部隊、軍なしの敵）",
	"story_fantasy_evolve_sortie": "ストーリー: FANTASY の物語の演習「分かれ道」の出撃準備（レベル 2 から始まるパラディンとソーサラーに、レベルが出る）",
	"story_boss_mvp": "ストーリー: FANTASY の物語の「峠の番人」（勝ち方は中ボスの撃破だけ）に、敵の駒にダメージを与えずに勝ったリザルト（MVP は中ボスへのダメージで決まる）",
	"story_fantasy_evolve": "ストーリー: FANTASY の物語の演習「分かれ道」で、あと 1 撃で進化するパラディンが盾役を攻撃し、進化先を選ぶところ",
	"story_fantasy_main_list": "ストーリー: FANTASY の物語の演習を終え、本編の 1 話目をクリアしたあとの話の一覧（本編のカード、増えた持ち物とコスト上限）",
	"story_split_sortie": "ストーリー: FANTASY の物語「岩山の合流」の出撃準備（味方が岩山の南と北に分かれて始まる。置けるマスが 2 か所に出る）",
	"story_split_placed": "ストーリー: 「岩山の合流」の出撃準備で、南の隊の駒を北の置けるマスへ移したところ",
	"story_split_talk": "ストーリー: 「岩山の合流」の前の会話（北に取り残されたセリスが話している。右は敵の話し手「連邦の伍長」）",
	"story_split_start": "ストーリー: 「岩山の合流」の対戦の始めを、いちばん引いて見ている（南と北に分かれた味方、北の台地のそばの敵）",
	"story_quarry_start": "ストーリー: MILITARY の物語の最後の話「縫い目の発破」の対戦の始めを、いちばん引いて見ている（結晶の採掘場。樽の多い盤、正面と西の脇に分かれた味方）",
	"story_vale_start": "ストーリー: FANTASY の物語の最後の話「墓守の眠り」の対戦の始めを、いちばん引いて見ている（縫い目の谷。ポータルの多い盤、奥に墓守と骨の群れ）",
	"story_fantasy_forest_sortie": "ストーリー: FANTASY の物語の「森の守り」（リュエルの森）の出撃準備（既定の編成、勝ち方、敵の部隊）",
	"story_fantasy_forest_wide": "ストーリー: リュエルの森（FANTASY の物語のための、森の多いマップ）を、いちばん引いて見ている",
	"story_fantasy_decks": "ストーリー: 部隊編成の「ストーリー用」を FANTASY の物語に切り替えて組むところ（FANTASY の駒だけ、最初のコスト上限）",
	"story_open_all": "ストーリー: 確かめ用の解放（F5）で全部の話を開いた話の一覧（左下の隅に印。どの話も選べる）",
	"story_list": "ストーリー: 物語を選んだあとの話の一覧（最初の話だけ選べる）",
	"story_list_cleared": "ストーリー: 本編の 1 話目をクリアしたあとの話の一覧（次の話が選べる。いま雇える駒が増えた）",
	"story_tutorial_list": "ストーリー: 何もクリアしていない話の一覧（頭のチュートリアルの話。番号に「（演習）」）",
	"story_tutorial_sortie": "ストーリー: チュートリアルの話（演習「撃ち合い」）の出撃準備（この話で覚えること、決まっている部隊）",
	"story_sortie": "ストーリー: 出撃準備（マップと初期位置、勝ち方、敵の部隊、出撃する部隊を選ぶ）",
	"story_unlocked_decks": "ストーリー: 全部の話をクリアしたあと、部隊編成の「ストーリー用」で組むところ（解放した駒・持ち物、上がったコストの上限）",
	"story_list_items": "ストーリー: 本編の 2 話目までクリアしたあとの話の一覧（カードの「クリアで増える」と、下の欄の持ち物・コストの上限）",
	"story_sortie_default": "ストーリー: 出撃準備で、既定の編成を選んでいるところ（第 1 話。解放した駒をまんべんなく、装備は 1 体に 1 つまで）",
	"decks_story": "部隊編成の「ストーリー用」で組んでいるところ（雇える駒は、いま解放した駒だけ。まだ持たせられない持ち物は「未解放」）",
	"story_talk_log": "ストーリー: 対戦の前の会話の途中で開いた会話のログ（これまでの文を、話し手の札と文で並べる。ホイールと矢印で遡る）",
	"story_talk": "ストーリー: 話の一覧で選んで始まる、対戦の前の会話（敵の話し手が話している。右の姿が明るく大きく、左の人の軍の話し手は暗く小さい）",
	"story_talk_drill": "ストーリー: チュートリアルの最初の話の前の会話（人の軍の曹長が話している。左の姿は進化後のシールドトルーパー）",
	"story_fantasy_talk": "ストーリー: FANTASY の物語の最初の話の前の会話（人の話し手「導師」。進化後のプリーストの姿）",
	"story_talk_squad": "ストーリー: 部隊の中の人が話している対戦の前の会話（岩山の掃討。左の所の姿が、話した人に入れ替わる。右は敵の話し手）",
	"story_rivals_ridge": "ストーリー: MILITARY の物語「尾根の小道」の前の会話（左にハーデン、右にイェルダ。見分けが付くか）",
	"story_rivals_forest": "ストーリー: FANTASY の物語「森の守り」の前の会話（左にイェルダ、右にハーデン。どちらも将。見分けが付くか）",
	"story_talk_narration": "ストーリー: 会話の頭の地の文（「尾根の小道」の前。名前の札なし、文を真ん中に明朝で。左右の姿は暗い）",
	"story_talk_allies": "ストーリー: 敵の軍が出てこない会話（演習「手当て」の前。最初に話した人が左、ほかの人が右に立って向き合う）",
	"story_start": "ストーリー: 話の対戦の始め（手で作ったマップ「尾根の小道」、決め打ちの敵）",
	"story_wide": "ストーリー: 話の対戦を、いちばん引いて見ている（引きの上限は盤の大きさに合わせる）",
	"story_result": "ストーリー: 話の対戦に勝った決着の画面（「次へ」が出る）",
	"story_defeat": "ストーリー: 話の対戦に負けた決着の画面（Enter で「同じマップで再戦」。「部隊を選び直す」で出撃準備へ戻れる）",
	"story_talk_menu": "ストーリー: 会話の場面で開いたシステムメニュー（閉じるボタンが「会話へ戻る」）",
	"story_decks_detour": "ストーリー: 出撃準備の「部隊編成」で開いた編成（ストーリー用だけ。「出撃準備へ戻る」）",
	"story_after": "ストーリー: 勝ったあとの会話（決着の画面の「次へ」のあと）",
	"story_unlock": "ストーリー: あとの会話の最後の、解放した駒の知らせ（金の縁の札と、駒の額。「飛ばす」でもここで止まる）",
	"story_next_choice": "ストーリー: あとの会話を読み終えて、「次の話へ」「話の一覧へ」を選ぶところ（選ぶ間は「スキップ」を出さない）",
	"story_battle_menu": "ストーリー: 話の対戦の途中で開いたシステムメニュー（「話の一覧へ戻る」がある）",
	"story_item_unlock": "ストーリー: ストーリー専用の持ち物の知らせ（持ち物の印と効果）",
	"story_items_decks": "ストーリー: FANTASY の物語を全部クリアしたあとの部隊編成（並ぶ持ち物が増えた。重ねられない持ち物は理由つき）",
	"story_items_military": "ストーリー: MILITARY の物語を全部クリアしたあとの部隊編成（コマンドーを選んでいて、遠眼鏡は「後衛専用」で灰色）",
	"story_hold_sortie": "ストーリー: 守り切る話（第 3 話）の出撃準備（勝ち方の文の先頭に「N ターン目の終わりまで守り切る」）",
	"story_hold_battle": "ストーリー: 守り切る話の対戦の途中（上の帯の勝ち方の札に「あと N ターン守り切れば勝ち」）",
	"story_hold_last": "ストーリー: 守り切る話の最後のターン（勝ち方の札が「最後のターン: 守り切れば勝ち」で、赤く目立つ）",
	"story_hold_result": "ストーリー: 守り切る話で、最後のターンの終わりまで持ちこたえて勝った決着の画面（「最後まで守り切った」）",
	"story_rout_sortie": "ストーリー: 全滅させる話（第 4 話）の出撃準備（2 つ目の手で作ったマップ「結晶の岩山」。勝ち方は「敵を全滅させれば勝ち」だけ）",
	"story_rout_start": "ストーリー: 全滅させる話の対戦の始め（結晶の岩山を、双子結晶の見た目で。上の帯の勝ち方の札「勝ち: 敵の全滅（将を倒しても終わらない）」）",
	"story_boss_sortie": "ストーリー: 中ボスを倒す演習（「結晶の番人」）の出撃準備（勝ち方は「中ボスを倒せば勝ち。敵の将を倒しても終わらない。」だけ）",
	"story_boss_start": "ストーリー: 中ボスを倒す演習の対戦の始め（上の帯の勝ち方の札「勝ち: 中ボスの撃破（将を倒しても終わらない）」）",
	"story_rout_wide": "ストーリー: 結晶の岩山を、いちばん引いて見ている（岩山と、両端の回り道、真ん中のポータル）",
	"story_monster_talk": "ストーリー: 魔物の群れの話の、対戦の前の会話（将のいない群れ。敵の話し手「骨の術師」の札と、骸骨術師の姿）",
	"story_horde_raise": "ストーリー: 将のいない群れの話「古戦場の亡者」で、骸骨術師が骨起こしで骸骨兵を起こしたあとの人の番（術師に寄って見る。旗の下は空）",
	"story_drums_talk": "ストーリー: FANTASY の物語「骨の太鼓」の前の会話（敵の話し手「骨の鼓手」の札と、骸骨鼓手の姿）",
	"story_drums_battle": "ストーリー: 「骨の太鼓」で、骸骨鼓手が骨太鼓を鳴らしたあとの人の番（周りの骨に突撃。突撃の付いた骸骨兵にマウスを乗せた駒の情報。上の帯の札は「勝ち: 敵の全滅」）",
	"story_monster_sortie": "ストーリー: 魔物の群れの話（軍に属さない敵）の出撃準備（敵の部隊は「軍なし」の骸骨）",
	"story_sortie_detail": "ストーリー: 出撃準備で、味方の駒のアイコン（持ち物つき）を押して詳しい説明を開いたところ",
	"story_sortie_hover": "ストーリー: 出撃準備の初期位置で、名前のいちばん長い駒にマウスを乗せたところ（駒の欄の中身が替わっても、板もまわりも動かない。story_sortie と並べる）",
	"story_sortie_placed": "ストーリー: 出撃準備の初期位置で、駒を 1 体動かし、もう 1 体を選んでいるところ（「おまかせ」が押せる）",
	"story_monster_detail": "ストーリー: 魔物の群れの話の出撃準備で、敵の骸骨のアイコンを押して詳しい説明を開いたところ",
	"story_monster_start": "ストーリー: 魔物の群れの話の対戦の始め（古戦場。骸骨兵・骸骨射手・骸骨重兵の群れに寄って見る）",
	"story_monster_king": "ストーリー: 将のいる魔物の群れの話（墓守）で、敵の将（骸骨の将の姿。ルールの上では将）にマウスを乗せた駒の情報と、敵の将の途中の台詞（骸骨の将のアイコン）",
	"story_monster_info": "ストーリー: 魔物の群れの話で、骸骨重兵にマウスを乗せた駒の情報（所属は「魔物」。スキル・持ち物の欄は無い）",
	"story_battle_talk_hold": "ストーリー: 遊ぶときの対戦の途中の会話（送られるまで盤を止める。帯の右に送りの印、下の帯に「クリック・Enter: 台詞を送る」）",
	"story_battle_talk": "ストーリー: 対戦の途中の会話（始めに台詞のある最初の話。上の帯のすぐ下の真ん中の、細い帯。対戦は止めない。ログにも残る）",
	"story_cleared": "ストーリー: 全部の話をクリアしたあとのタイトル（「ストーリー」に済みの印）",
}
## 場面を作る対戦の最初の種。
const SEED := 1
## SEED の対戦で場面を作れなかったときに、続けて試す種の数（ルールや数値が変わると、同じ種でも場面が来なくなるため。_run）。
## どの種でも作れなかった場面は飛ばし、ほかの場面を撮ってから、まとめて失敗にする。
const MORE_SEEDS := 8
## 撮る前に待つ時間（秒）。番の知らせが消え、カメラが寄り終わるまで。
const SETTLE := 1.8
## 番の知らせが消えるのを、SETTLE のあとさらに待つ上限（秒）。
const BANNER_WAIT := 3.0
## CPU どうしで進める行動の数の上限（場面が来なければ、撮らずに失敗にする）。
const MAX_ACTIONS := 3000
const JPEG_QUALITY := 0.82
## `--frame-time` で測るコマの数。
const FRAME_TIME_FRAMES := 40

var _app: Node
## いまの対戦の画面（battle_screen.gd）。アプリが対戦の場面にいる間だけ使う。
var _scene: Node
var _out := ""
## 場面を作るだけで撮らない（`--dry-run`。画面なしの長い検査で、場面が作れることだけを確かめる）。
var _dry_run := false
## 撮る前に、その場面の 1 コマの時間を測って出す（`--frame-time`。見た目を変えた前後の重さを比べる）。
var _frame_time := false
var _names: Array[String] = []
var _cpu := CpuPlayer.new()
var _battle: Battle
var _stats: BattleStats
## _battle の始めからのログ（相手を CPU として書く）。
var _log: BattleLog
## いまの対戦のマップ（versus_fields.gd の鍵）。
var _field: StringName = VersusFields.PLAIN
## いまの対戦の種（SEED から。場面を作れなければ _run が替える）。
var _seed := SEED
## 場面が、演出の途中を撮る時刻まで自分で待ったか（真なら、再生の終わりも知らせが消えるのも待たずに、すぐ撮る）。
var _mid_animation := false
## 演出の途中を撮る場面は、時間をこの速さに落として進める（描画の遅い環境では 1 コマが長く、短い演出を飛び越えてしまうため）。
const SLOW_MOTION := 0.15


func _init(app: Node) -> void:
	_app = app


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var shots := _arg(args, "--shots")
	_out = _arg(args, "--out")
	_dry_run = args.has("--dry-run")
	_frame_time = args.has("--frame-time")
	if shots == "" or (_out == "" and not _dry_run):
		_quit("screenshots: --shots と --out（か --dry-run）を指定する（場面: %s）" % ", ".join(SCENES.keys()), 1)
		return
	for name: String in (SCENES.keys() if shots == "all" else Array(shots.split(","))):
		if name.begins_with(SCAPE):
			if not _scape_known(name):
				_quit("screenshots: 知らない景色の場面: %s（%s）" % [name, SCAPE_USAGE], 1)
				return
		elif not SCENES.has(name):
			_quit("screenshots: 知らない場面: %s（場面: %s）" % [name, ", ".join(SCENES.keys())], 1)
			return
		_names.append(name)
	if not _dry_run:
		DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var failed: Array[String] = []
	for name: String in _names:
		var ok := false
		for i in MORE_SEEDS + 1:
			await _reset(SEED + i)
			ok = _scape(name) if name.begins_with(SCAPE) else await call("_scene_" + name)
			if ok:
				if i > 0:
					print("screenshots: 場面 %s は種 %d で作れた" % [name, _seed])
				break
		if not ok:
			printerr("screenshots: 場面 %s を作れなかった（種 %d〜%d）" % [name, SEED, SEED + MORE_SEEDS])
			failed.append(name)
			continue
		if _dry_run:
			print("screenshots: 場面 %s を作れた" % name)
			if _mid_animation:
				_scene.set_time_scale_base(1.0)
			while _app.current_id() == SceneFlow.BATTLE and _scene.is_busy() and not _scene.setup_panel().visible and not _app.system_menu().is_open() and not _app.quit_window.is_open() and not _scene.log_panel().is_open() and not _scene.is_talk_holding() and not _scene.unit_detail().visible:
				await get_tree().process_frame
			continue
		if _mid_animation:
			if not await _capture(name):
				return
			_scene.set_time_scale_base(1.0)
			while _scene.is_busy():  # 次の場面を作る前に、再生を終わらせる
				await get_tree().process_frame
			continue
		while _app.current_id() == SceneFlow.BATTLE and _scene.is_busy() and not _scene.setup_panel().visible and not _app.system_menu().is_open() and not _app.quit_window.is_open() and not _scene.log_panel().is_open() and not _scene.is_talk_holding() and not _scene.unit_detail().visible:
			await get_tree().process_frame
		_park_mouse()
		# システムメニューを開いている間は時間が止まるので、待つのは時間の速さに依らない時計で測る。
		await get_tree().create_timer(SETTLE, true, false, true).timeout
		await _banner_gone()
		if not await _capture(name):
			return
	if not failed.is_empty():
		_quit("screenshots: 作れなかった場面: %s" % ", ".join(failed), 1)
		return
	_quit("screenshots: OK", 0)


## 設定を既定に戻したあとも、`--unit-look <組の名前>` で選んだ駒の見た目の組は保つ（tools/screenshots.sh の --unit-look=）。
func _keep_unit_look() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--unit-look")
	if at != -1 and at + 1 < args.size():
		_app.context.settings.set_value(&"unit_look", UnitLooks.ORDER.find(StringName(args[at + 1])))


## 場面を作る前に、前の場面の状態を戻し、種 seed の新しい対戦を用意する。
func _reset(seed: int) -> void:
	_app.system_menu().close()
	_app.context.settings.reset_all()
	_keep_unit_look()
	if OS.get_cmdline_user_args().has("--no-effects"):
		_app.context.settings.set_value(&"screen_effects", false)  # tools/screenshots.sh の --no-effects（画面の効果を切って撮る）
	for number in range(1, 4):
		_app.context.slots.remove(number)  # 前の場面が書いたセーブのスロットを持ち越さない（取っておく先は無いので、覚えているものだけ）
	_app.context.story.load_data({})  # 前の場面（ストーリー）のクリアの記録を持ち越さない
	_app.context.story.open_all = false  # 前の場面（story_open_all）の確かめ用の解放（F5）も持ち越さない（残ると、記録に書かず、隅に印が出る）
	_app.context.story.choose_campaign(Story.military())  # 前の場面が選んだ物語も持ち越さない
	if _app.current_id() != SceneFlow.BATTLE or _app.context.run != null:
		_app.context.run = null  # 流れ（ストーリーの話）の中の対戦の場面は使わない
		_app.context.match_choice.cpu_opponent = false
		await _app.go(SceneFlow.BATTLE)
	_scene = _app.current_scene()
	_scene.log_panel().close()
	_scene.unit_detail().close_detail()
	_scene.setup_panel().visible = false
	_scene.set_opponent(false)  # 撮る間は CPU に番を進めさせない
	_scene.hover(Vector2i(-1, -1))  # 前の場面で乗せたことにしたマウスを戻す
	_scene.hover_menu_item(&"")  # 前の場面（menu_note）でメニューの項目に乗せたことにしたマウスも戻す（残ると予測のパネルが出ない）
	if _scene.is_threat_shown():
		_scene.toggle_threat()  # 前の場面で出した、敵の全員の脅威範囲を消す
	_field = VersusFields.PLAIN
	_seed = seed
	_new_battle()
	_aim(22.0, 0.0, OrbitCamera.DEFAULT_PITCH)  # 前の場面で動かしたカメラを戻す（ほかの場面は、始めの向きと角度で撮る）
	_mid_animation = false


## いまの画面を撮って書く。書けなければ終わらせて偽を返す。
func _capture(name: String) -> bool:
	if _frame_time:
		var started := Time.get_ticks_usec()
		for i in FRAME_TIME_FRAMES:
			await RenderingServer.frame_post_draw
		print("screenshots: %s の 1 コマ %.1f ms（%d コマの平均）" % [name, (Time.get_ticks_usec() - started) / 1000.0 / FRAME_TIME_FRAMES, FRAME_TIME_FRAMES])
	await RenderingServer.frame_post_draw
	var path := _out.path_join(name + ".jpg")
	var error := get_viewport().get_texture().get_image().save_jpg(path, JPEG_QUALITY)
	if error != OK:
		_quit("screenshots: %s を書けなかった（%s）" % [path, error_string(error)], 1)
		return false
	print("screenshots: %s" % path)
	return true


# ---- 場面 ----


func _scene_title() -> bool:
	await _app.go(SceneFlow.TITLE)
	return _app.current_id() == SceneFlow.TITLE


func _scene_map_select() -> bool:
	await _app.go(SceneFlow.MAP_SELECT)
	return _app.current_id() == SceneFlow.MAP_SELECT


func _scene_map_hover() -> bool:
	if not await _scene_map_select():
		return false
	_app.current_scene().hover(VersusFields.LABYRINTH)
	_app.current_scene().show_scape_now()  # 背景の景色が、乗せたマップのものに替わるのを待たない
	return _app.current_scene().hovered_field() == VersusFields.LABYRINTH


func _scene_map_hover_pass() -> bool:
	return await _map_hover(VersusFields.BOULDER_PASS)


func _scene_map_hover_twin() -> bool:
	return await _map_hover(VersusFields.TWIN_SPRINGS)


func _map_hover(field: StringName) -> bool:
	if not await _scene_map_select():
		return false
	_app.current_scene().hover(field)
	_app.current_scene().show_scape_now()
	return _app.current_scene().hovered_field() == field


func _scene_setup_ridge() -> bool:
	_app.context.match_choice = MatchChoice.new()
	_app.context.match_choice.field = VersusFields.RIDGE_PATH
	await _app.go(SceneFlow.SETUP)
	return _app.current_id() == SceneFlow.SETUP


## 一覧の最初の手で作ったマップ（画面に出していないものも）。無ければ空。
func _first_hand_field() -> StringName:
	for field in VersusFields.all_ids():
		if not VersusFields.is_generated(field):
			return field
	return &""


func _scene_versus_hand_start() -> bool:
	_field = _first_hand_field()
	if _field == &"":
		return false
	_new_battle()
	_show()
	return true


## 一覧の最後の手で作ったマップ（画面に出していないものも）。無ければ空。
func _last_hand_field() -> StringName:
	var last: StringName = &""
	for field in VersusFields.all_ids():
		if not VersusFields.is_generated(field):
			last = field
	return last


func _scene_versus_hand_last_start() -> bool:
	_field = _last_hand_field()
	if _field == &"":
		return false
	_new_battle()
	_show()
	return true


func _scene_versus_hand_result() -> bool:
	_field = _first_hand_field()
	if _field == &"":
		return false
	_new_battle()
	return await _cpu_result(true)


func _scene_title_menu() -> bool:
	await _app.go(SceneFlow.TITLE)
	_app.open_menu()
	return _app.system_menu().is_open()


## 部隊の一覧に、見本の部隊を入れる（検査とスクリーンショットでは、取っておく先が無いので、毎回ここで作る）。
func _fill_decks() -> void:
	var library: RefCounted = _app.context.decks
	library.load_data({"decks": []})
	var first := Deck.new(UnitKind.Army.MILITARY)
	for kind: UnitKind.Id in [UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SNIPER, UnitKind.Id.SNIPER, UnitKind.Id.COMMANDO, UnitKind.Id.MEDIC]:
		first.add(kind)
	first.entries[0].equip(Equipment.Id.IRON_SHIELD)
	first.entries[0].equip(Equipment.Id.IRON_SHIELD)
	first.entries[3].equip(Equipment.Id.SPEED_BOOTS)
	library.add("狙撃の布陣", first)
	var second := Deck.new(UnitKind.Army.FANTASY)
	for kind: UnitKind.Id in [UnitKind.Id.PALADIN, UnitKind.Id.SPELLBLADE, UnitKind.Id.SPELLBLADE, UnitKind.Id.PRIEST]:
		second.add(kind)
	second.entries[1].equip(Equipment.Id.SPEED_BOOTS)
	library.add("速攻の騎士団", second)
	var third := Deck.new(UnitKind.Army.MILITARY)
	for i in 6:
		third.add(UnitKind.Id.SHIELD_TROOPER)
	third.entries[0].equip(Equipment.Id.IRON_SHIELD)
	library.add("盾の壁（予算の見直し前）", third)


func _deck_scene() -> Node:
	_fill_decks()
	await _app.go(SceneFlow.DECKS)
	return _app.current_scene() if _app.current_id() == SceneFlow.DECKS else null


func _scene_deck_list() -> bool:
	var screen: Node = await _deck_scene()
	if screen == null:
		return false
	screen.select_saved(_app.context.decks.items()[2].id)
	return screen.list_selected() != ""


func _scene_deck_delete() -> bool:
	var screen: Node = await _deck_scene()
	if screen == null:
		return false
	screen.press_delete()
	return screen.is_dialog_open()


func _scene_deck_rename() -> bool:
	var screen: Node = await _deck_scene()
	if screen == null:
		return false
	screen.press_rename()
	return screen.is_dialog_open()


func _scene_deck_army() -> bool:
	var screen: Node = await _deck_scene()
	if screen == null:
		return false
	screen.press_new()
	return screen.is_choosing_army()


func _scene_deck_none() -> bool:
	var screen: Node = await _deck_scene()
	if screen == null:
		return false
	_app.context.decks.load_data({"decks": []})
	screen.show_list()
	return screen.listed_ids().is_empty()


func _scene_deck_empty() -> bool:
	var screen: Node = await _deck_scene()
	if screen == null:
		return false
	screen.press_new()
	screen.choose_new_army(UnitKind.Army.MILITARY)
	return screen.is_editing()


## 組み直す部隊（一覧の最初の部隊）を開く。
func _deck_editor() -> Node:
	var screen: Node = await _deck_scene()
	if screen == null:
		return null
	screen.select_saved(_app.context.decks.items()[0].id)
	screen.press_edit()
	return screen if screen.is_editing() else null


func _scene_deck_built() -> bool:
	var screen: Node = await _deck_editor()
	if screen == null:
		return false
	screen.hover_kind(UnitKind.Id.SNIPER)
	return true


func _scene_deck_equip() -> bool:
	var screen: Node = await _deck_editor()
	if screen == null:
		return false
	screen.select_entry(3)
	screen.equip(Equipment.Id.SPEED_BOOTS)
	return screen.selected_entry() == 3


func _scene_deck_unit_detail() -> bool:
	var screen: Node = await _deck_editor()
	if screen == null:
		return false
	screen.select_entry(0)
	screen.equip(Equipment.Id.IRON_SHIELD)
	screen.equip(Equipment.Id.IRON_SHIELD)
	screen.equip(Equipment.Id.SPEED_BOOTS)
	screen.press_unit_detail()
	return screen.unit_detail() != null and screen.unit_detail().visible


func _scene_deck_over() -> bool:
	var screen: Node = await _deck_editor()
	if screen == null:
		return false
	screen.hire(UnitKind.Id.SHIELD_TROOPER)
	screen.equip(Equipment.Id.IRON_SHIELD)
	screen.equip(Equipment.Id.IRON_SHIELD)
	screen.equip(Equipment.Id.SPEED_BOOTS)
	return not screen.can_save()


func _scene_setup_deck() -> bool:
	_fill_decks()
	_app.context.match_choice = MatchChoice.new()
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	var panel: Node = _app.current_scene().setup_panel()
	if not panel.choose_deck(Unit.Side.PLAYER1, _app.context.decks.items()[0].id):
		return false
	_park_mouse()
	await get_tree().process_frame
	panel.open_deck_picker(Unit.Side.PLAYER1)
	return true


func _scene_setup_unit_detail() -> bool:
	if not await _scene_setup_preview():
		return false
	var preview: Control = _app.current_scene().setup_panel().preview()
	preview.press_card(1)
	return preview.detail().visible


func _scene_setup_placement() -> bool:
	_app.context.match_choice = MatchChoice.new()
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	var panel: Node = _app.current_scene().setup_panel()
	panel.open_placement(Unit.Side.PLAYER1)
	return _move_and_pick(panel.placement_dialog().deploy_map())


## 初期位置の縮図 deploy で、最初の駒を空いている置けるマスへ動かし、2 番目の駒を選んでおく。
func _move_and_pick(deploy: Control) -> bool:
	var own: Array[Vector2i] = deploy.unit_cells()
	var open: Array = deploy.zone().filter(func(cell: Vector2i) -> bool: return not own.has(cell))
	if own.size() < 2 or open.is_empty():
		return false
	deploy.press_cell(own[0])
	deploy.press_cell(open[open.size() - 1])
	deploy.press_cell(own[1])
	_park_mouse()
	return deploy.selected() == 1


func _scene_setup_preview() -> bool:
	_fill_decks()
	_app.context.match_choice = MatchChoice.new()
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	var panel: Node = _app.current_scene().setup_panel()
	panel.choose_deck(Unit.Side.PLAYER1, _app.context.decks.items()[0].id)
	panel.open_preview(Unit.Side.PLAYER2)
	_park_mouse()
	return panel.preview().visible


func _scene_setup_cpu_deck() -> bool:
	_fill_decks()
	_app.context.match_choice = MatchChoice.new()
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	var panel: Node = _app.current_scene().setup_panel()
	if not panel.choose_deck(Unit.Side.PLAYER2, MatchChoice.RANDOM):
		return false
	_park_mouse()
	await get_tree().process_frame
	panel.open_deck_picker(Unit.Side.PLAYER2)
	return true


func _scene_setup_cpu_random() -> bool:
	_app.context.match_choice = MatchChoice.new()
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	var panel: Node = _app.current_scene().setup_panel()
	panel.choose_deck(Unit.Side.PLAYER2, MatchChoice.RANDOM)
	panel.confirm()
	await _app.scene_changed
	if _app.current_id() != SceneFlow.BATTLE:
		return false
	_scene = _app.current_scene()
	var battle_scene: Node = _scene
	for i in 120:
		if not battle_scene.is_busy():
			break
		await get_tree().process_frame
	battle_scene.open_setup()
	var shown: Node = battle_scene.setup_panel()
	if not shown.visible or not shown.can_preview(Unit.Side.PLAYER2):
		return false
	shown.open_preview(Unit.Side.PLAYER2)
	_park_mouse()
	return shown.preview().visible


## 本物の入力で、手番ランダムの後手の初期位置を確かめる: 対戦設定の「初期位置」で最初の駒を端へ動かし、手番を「ランダム」にして始め、
## 後手を引く種まで「同じ設定のまま新しい種」で始め直す。後手の最初の駒が、点対称に返したマスにいなければ偽。
func _scene_setup_random_second() -> bool:
	var choice := MatchChoice.new()
	choice.field = VersusFields.TWIN_SPRINGS
	_app.context.match_choice = choice
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	var panel: Node = _app.current_scene().setup_panel()
	panel.open_placement(Unit.Side.PLAYER1)
	var dialog: Control = panel.placement_dialog()
	var deploy: Control = dialog.deploy_map()
	var own: Array[Vector2i] = deploy.unit_cells()
	var open: Array = deploy.zone().filter(func(cell: Vector2i) -> bool: return not own.has(cell))
	if own.is_empty() or open.is_empty():
		return false
	# 盤の端の側（本陣が左下なので、列の小さいほう）の、空いている置けるマスへ。
	open.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	deploy.press_cell(own[0])
	deploy.press_cell(open[0])
	dialog.close_dialog()
	var offset: Vector2i = open[0] - panel.current_choice().placement_preview(Unit.Side.PLAYER1, panel.PLACEMENT_SEED)[1].board.hq_cells[0]
	panel.choose_random_side()
	panel.confirm()
	await _app.scene_changed
	if _app.current_id() != SceneFlow.BATTLE:
		return false
	_scene = _app.current_scene()
	for battle_seed in range(1, 60):
		if _scene.source.cpu_side() == Unit.Side.PLAYER1:
			break
		for i in 120:
			if not _scene.is_busy():
				break
			await get_tree().process_frame
		_scene.start_battle(battle_seed)
	if _scene.source.cpu_side() != Unit.Side.PLAYER1:
		return false
	var battle: Battle = _scene.battle
	var first: Array = battle.units.filter(func(unit: Unit) -> bool: return unit.side == Unit.Side.PLAYER2 and unit.kind != UnitKind.Id.KING)
	if first.is_empty() or first[0].cell != battle.board.hq_cells[Unit.Side.PLAYER2] - offset:
		push_error("screenshots: 後手の最初の駒が %s（点対称に返したマスは %s）" % [first[0].cell if not first.is_empty() else null, battle.board.hq_cells[1] - offset])
		return false
	for i in 600:
		if not _scene.is_busy():
			break
		await get_tree().process_frame
	_park_mouse()
	return true


func _scene_setup_random() -> bool:
	_app.context.match_choice = MatchChoice.new()
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	_app.current_scene().setup_panel().choose_random_side()
	_park_mouse()
	return true


func _scene_setup_battery() -> bool:
	_app.context.match_choice = MatchChoice.new()
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	_app.current_scene().setup_panel().choose_trial(TrialRules.BATTERY, true)
	_park_mouse()
	return _app.current_scene().setup_panel().current_choice().has_trial(TrialRules.BATTERY)


func _scene_setup_stronghold() -> bool:
	_app.context.match_choice = MatchChoice.new()
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	_app.current_scene().setup_panel().choose_trial(TrialRules.STRONGHOLD, true)
	_park_mouse()
	return _app.current_scene().setup_panel().current_choice().has_trial(TrialRules.STRONGHOLD)


func _scene_setup_tactics() -> bool:
	_app.context.match_choice = MatchChoice.new()
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	var panel: Variant = _app.current_scene().setup_panel()
	panel.choose_trial(TrialRules.TACTICS, true)
	panel.choose_tactic(Unit.Side.PLAYER1, Tactics.Id.WARD)
	_park_mouse()
	return panel.current_choice().has_trial(TrialRules.TACTICS)


func _scene_setup() -> bool:
	_app.context.match_choice = MatchChoice.new()  # 遊ぶときの始めと同じ（相手は CPU）で開く
	await _app.go(SceneFlow.SETUP)
	return _app.current_id() == SceneFlow.SETUP


func _scene_setup_again() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	_scene.open_setup()
	return _scene.setup_panel().is_cancellable()


func _scene_setup_confirm() -> bool:
	if not _scene_setup_again():
		return false
	_scene.setup_panel().press_map()
	return _scene.setup_panel().confirming_text() != ""


## 対戦の途中の盤面を出し、カメラが落ち着いてからシステムメニューを開く（開くと時間が止まる）。
func _open_system_menu() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	await get_tree().create_timer(SETTLE).timeout
	_scene.press_escape()
	return _app.system_menu().is_open()


func _scene_system_menu() -> bool:
	return await _open_system_menu()


func _scene_system_quit() -> bool:
	if not await _open_system_menu():
		return false
	_app.system_menu().press(&"quit")
	return _app.system_menu().confirming() == &"quit"


func _scene_window_close() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	await get_tree().create_timer(SETTLE).timeout
	_app.request_close()
	return _app.quit_window.is_open()


func _scene_settings() -> bool:
	if not await _open_system_menu():
		return false
	_app.system_menu().press(&"settings")
	_scene.settings.set_value(&"mouse_sensitivity", 150)
	return _app.system_menu().is_settings_open()


func _scene_settings_screen() -> bool:
	if not await _scene_settings():
		return false
	_scene.settings.set_value(&"fullscreen", true)  # 撮る間は窓に触らない（app.gd）ので、値だけが変わって見える
	await get_tree().process_frame
	_app.system_menu().settings_panel().scroll_to_end()
	return true


func _scene_menu_note() -> bool:
	if not await _scene_skill():
		return false
	_scene.press_skill()  # 対象を選ぶのをやめて、メニューへ戻る
	_scene.hover_menu_item(&"skill")
	return _scene.menu_ids().has(&"skill")


func _scene_start() -> bool:
	_show()
	return true


func _scene_minimap_pointed() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	var hq: Vector2i = _battle.board.hq_cells[Unit.Side.PLAYER2]
	_scene.point_minimap(Vector2(hq) + Vector2(0.5, 3.5))
	return _scene.minimap_rect().has_area()


func _scene_minimap_hidden() -> bool:
	_show()
	_scene.settings.set_value(&"show_minimap", false)
	return true


func _scene_phase_camera() -> bool:
	# 相手（プレイヤー2）の番の終わりの手前まで進め、その番の終わりだけを画面に通す（中立の番のあと、自分の番の始めにカメラが寄る）。
	# CPU は将を最後に動かすので、そのままでは将に寄るのと見分けが付かない。撮る番だけ、自分の番の始めに将を先に待機させる。
	var events: Array[BattleEvent] = []
	var watch := func(happened: Array[BattleEvent]) -> void: events.append_array(happened)
	if not _advance(func() -> bool: return _battle.turn >= 4 and _battle.phase == Unit.Side.PLAYER1, watch):
		return false
	var king := Queries.king_of(_battle, Unit.Side.PLAYER1)
	if king != null and _battle.can_apply(WaitAction.new(king.id)):
		var result := _battle.apply(WaitAction.new(king.id))
		_stats.feed_all(result.events)
		_log.feed_all(result.events)
		events.append_array(result.events)
	if not _advance(func() -> bool: return _battle.phase == Unit.Side.PLAYER2 and _cpu.next_action(_battle) is EndPhaseAction, watch):
		return false
	_show()
	var focus: Unit = _scene.phase_focus_after(events, Unit.Side.PLAYER1)
	await _scene.act(EndPhaseAction.new())
	if focus == null or _battle.phase != Unit.Side.PLAYER1:
		return false
	_scene.mark_cell(focus.cell)  # 寄った駒を示す（撮るためだけ）
	print("screenshots: フェーズの始めに寄った駒 %s %s" % [Names.kind(focus.kind), focus.cell])
	return true


func _scene_pitch_low() -> bool:
	_show()
	_scene.set_camera_pitch(OrbitCamera.MIN_PITCH)
	return true


func _scene_pitch_high() -> bool:
	_show()
	_scene.set_camera_pitch(OrbitCamera.MAX_PITCH)
	return true


func _scene_move() -> bool:
	_show()
	# 動ける範囲のいちばん広い駒を選ぶ。
	var best: Unit = null
	var most := -1
	for unit in _own_units():
		var count := Queries.move_cells(_battle, unit).size()
		if count > most:
			best = unit
			most = count
	_scene.click_cell(best.cell)
	return true


func _scene_cell() -> bool:
	_show()
	# 樽（無ければ森）のマスをクリックする。
	var cell := Vector2i(-1, -1)
	if not _battle.board.barrel_cells.is_empty():
		cell = _battle.board.barrel_cells[0]
	else:
		for y in _battle.board.size.y:
			for x in _battle.board.size.x:
				if cell.x < 0 and _battle.board.terrain_at(Vector2i(x, y)) == Terrain.Type.FOREST:
					cell = Vector2i(x, y)
	_scene.click_cell(cell)
	_scene.focus_camera(cell)
	return _scene.info_title().begins_with("マス")


## 動けば攻撃できる相手がいる駒と、その行き先（[駒, マス]）。無ければ空。
func _move_then_attack() -> Array:
	for unit in _own_units():
		if not _battle.can_act(unit) or UnitKind.role(unit.kind) == UnitKind.Role.HEALER:
			continue
		for cell: Vector2i in _battle.options(unit.id).move_cells:
			if cell == unit.cell:
				continue
			var trial := _battle.clone()
			trial.apply(MoveAction.new(unit.id, cell, false))
			if not trial.options(unit.id).attack_target_ids.is_empty():
				return [unit, cell]
	return []


func _scene_menu_moved() -> bool:
	if not _advance(func() -> bool: return _battle.phase != Unit.Side.NEUTRAL and not _move_then_attack().is_empty()):
		return false
	var found := _move_then_attack()
	var unit: Unit = found[0]
	_show()
	_scene.click_cell(unit.cell)
	await _scene.act(MoveAction.new(unit.id, found[1], false))
	_scene.focus_camera(unit.cell)
	return _scene.menu_ids().has(&"attack") and _scene.menu_ids().has(&"undo")


func _scene_menu_attack() -> bool:
	if not await _scene_menu_moved():
		return false
	return _scene.press_menu(&"attack") and _scene.is_choosing_target()


func _scene_menu_crowd() -> bool:
	# 両軍がぶつかったあとの、周りに駒のいちばん多い自分の駒。
	if not _advance(func() -> bool: return _battle.turn >= 4 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	var best: Unit = null
	var most := -1
	for unit in _own_units():
		if not _battle.can_act(unit):
			continue
		var near := 0
		for other in _battle.units:
			if other != unit and maxi(absi(other.cell.x - unit.cell.x), absi(other.cell.y - unit.cell.y)) <= 2:
				near += 1
		if near > most:
			best = unit
			most = near
	if best == null:
		return false
	_scene.click_cell(best.cell)
	_scene.focus_camera(best.cell)
	return not _scene.menu_ids().is_empty()


func _scene_menu_edge() -> bool:
	_show()
	# 盤の下の端にいちばん近い駒を選び、カメラをずらして、その駒を画面の右下の隅に寄せる。
	var best: Unit = null
	for unit in _own_units():
		if best == null or unit.cell.y > best.cell.y or (unit.cell.y == best.cell.y and unit.cell.x > best.cell.x):
			best = unit
	_scene.click_cell(best.cell)
	_scene.focus_camera(best.cell + Vector2i(-11, -4))
	return not _scene.menu_ids().is_empty()


func _scene_threat() -> bool:
	# 両軍が近づいた、ターン 3 のプレイヤー1 の番の始め。
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	# 自分の駒にいちばん近い、相手の駒（将は除く）を選ぶ。
	var best: Unit = null
	var nearest := 1 << 30
	for foe in _battle.units:
		if foe.side != 1 - _battle.phase or foe.kind == UnitKind.Id.KING:
			continue
		for unit in _own_units():
			var distance := _distance(foe.cell, unit.cell)
			if distance < nearest:
				best = foe
				nearest = distance
	if best == null:
		return false
	_scene.click_cell(best.cell)
	_scene.focus_camera(best.cell)
	return true


func _scene_inspect_moved() -> bool:
	if not await _scene_menu_moved():
		return false
	# 動いた駒にいちばん近い、攻撃の相手でない相手の駒（将と回復役は除く。相手の駒はクリックで攻撃してしまい、回復役には脅威範囲が無い）。
	var mover: Unit = _scene.selected_unit()
	var targets := _battle.options(mover.id).attack_target_ids
	var best: Unit = null
	var nearest := 1 << 30
	for foe in _battle.units:
		if foe.side != 1 - _battle.phase or foe.kind == UnitKind.Id.KING or targets.has(foe.id):
			continue
		if UnitKind.role(foe.kind) == UnitKind.Role.HEALER:
			continue
		if _distance(foe.cell, mover.cell) < nearest:
			best = foe
			nearest = _distance(foe.cell, mover.cell)
	if best == null:
		return false
	_scene.click_cell(best.cell)
	_look_at((BoardView.cell_center(best.cell) + BoardView.cell_center(mover.cell)) / 2.0)
	_aim(26.0, 0.0, OrbitCamera.DEFAULT_PITCH)
	return _scene.inspected_unit() == best and _scene.selected_unit() == mover


func _scene_threat_all() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	var unit := _own_units()[0]
	for own in _own_units():
		if own.kind != UnitKind.Id.KING and _battle.can_act(own):
			unit = own
			break
	_scene.click_cell(unit.cell)
	_scene.toggle_threat()
	_scene.focus_camera(unit.cell)
	return _scene.is_threat_shown()


func _scene_threat_pin_switch() -> bool:
	if not await _scene_threat():
		return false
	var shown: Array[bool] = _scene.pin_switch_state()
	return shown[0] and _scene.press_pin_switch() and _scene.pin_switch_state()[1]


func _scene_threat_pinned() -> bool:
	if not await _scene_threat_pin_switch():
		return false
	var first: Unit = _scene.inspected_unit()
	# もう 1 体: 留めた駒にいちばん近い、ほかの相手の駒（将は除く）。
	var second: Unit = null
	for foe in _battle.units:
		if foe.side == first.side and foe != first and foe.kind != UnitKind.Id.KING:
			if second == null or _distance(foe.cell, first.cell) < _distance(second.cell, first.cell):
				second = foe
	if second == null:
		return false
	_scene.click_cell(second.cell)
	_scene.press_pin_switch()
	_scene.cancel()  # 見るのをやめる（範囲は残る）
	_scene.toggle_threat()
	return _scene.pinned_ids().size() == 2 and _scene.is_threat_shown()


## field のマップで、敵の全員の脅威範囲を出し、自分の駒の近くの相手の駒を見る（斜線と、見ている駒の赤い塗りが重なる）。
func _threat_mix(field: StringName) -> bool:
	_field = field
	_new_battle()
	if not await _scene_threat():
		return false
	_scene.toggle_threat()
	return _scene.is_threat_shown() and not _scene.threat_painted_cells().is_empty()


func _scene_threat_mix_plain() -> bool:
	return await _threat_mix(VersusFields.PLAIN)


func _scene_threat_mix_labyrinth() -> bool:
	return await _threat_mix(VersusFields.LABYRINTH)


func _scene_threat_mix_twin_springs() -> bool:
	return await _threat_mix(VersusFields.TWIN_SPRINGS)


func _scene_forecast_attack() -> bool:
	if not await _scene_menu_moved():
		return false
	var mover: Unit = _scene.selected_unit()
	var target := _battle.unit_by_id(_battle.options(mover.id).attack_target_ids[0])
	_scene.hover(target.cell)
	return _scene.forecast_text() != ""


## 行動できる自分の駒が、いまの位置から倒せる相手（[駒, 相手]）。無ければ空。
func _defeat_now() -> Array:
	for unit in _own_units():
		if not _battle.can_act(unit):
			continue
		for target_id in _battle.options(unit.id).attack_target_ids:
			if Forecast.of(_battle, AttackAction.new(unit.id, target_id)).defeated_ids().has(target_id):
				return [unit, _battle.unit_by_id(target_id)]
	return []


func _scene_forecast_defeat() -> bool:
	if not _advance(func() -> bool: return _battle.phase != Unit.Side.NEUTRAL and not _defeat_now().is_empty()):
		return false
	var found := _defeat_now()
	_show()
	_scene.click_cell(found[0].cell)
	_look_at(BoardView.cell_center(found[1].cell))
	_scene.hover(found[1].cell)
	return _scene.forecast_text().contains("倒せる")


## 行動できる自分の駒が、スキルで相手を 2 体以上巻き込めるマス（[駒, マス]）。無ければ空。
func _skill_hits() -> Array:
	for unit in _own_units():
		if not _battle.can_act(unit):
			continue
		for cell in _battle.options(unit.id).skill_cells:
			var forecast := Forecast.of(_battle, UseSkillAction.new(unit.id, cell))
			var hits := 0
			for outcome in forecast.units:
				if outcome.hits > 0:
					hits += 1
			if hits >= 2:
				return [unit, cell]
	return []


func _scene_forecast_skill() -> bool:
	if not _advance(func() -> bool: return _battle.phase != Unit.Side.NEUTRAL and not _skill_hits().is_empty()):
		return false
	var found := _skill_hits()
	_show()
	_scene.click_cell(found[0].cell)
	_scene.press_skill()
	_look_at(BoardView.cell_center(found[1]))
	_scene.hover(found[1])
	return _scene.is_choosing_skill_target() and _scene.forecast_text() != ""


## 1 コマ進めてから、再生が終わるまで待つ。
func _idle() -> void:
	await get_tree().process_frame
	while _scene.is_busy():
		await get_tree().process_frame


## 自動の対戦の場面 inspection と同じ盤と駒で、既定のカメラの向きのまま攻撃の予測を出す（メニューと予測のパネルが近くに並ぶ）。
func _scene_forecast_small() -> bool:
	var board := Board.new(Vector2i(9, 5))
	board.hq_cells = [Vector2i(0, 4), Vector2i(8, 0)]
	_battle = Battle.new(board)
	_battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	_battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(8, 0))
	var trooper := _battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(1, 2))
	_battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER2, Vector2i(7, 2))
	var foe := _battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER2, Vector2i(4, 2))
	_battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(5, 4))
	_stats = BattleStats.new(_battle)
	_show()
	# 自動の対戦の inspection と同じ順に: 動いて取り消してから、相手の隣へ動き、メニューの「攻撃」で相手を選び始める。
	await _idle()
	_scene.click_cell(trooper.cell)
	_scene.click_cell(Vector2i(2, 2))
	await _idle()
	_scene.cancel()  # 移動を取り消す
	await _idle()
	_scene.click_cell(Vector2i(3, 2))
	await _idle()
	if trooper.cell != Vector2i(3, 2):
		return false
	# カメラが寄り終わってから、メニューの「攻撃」とマウスを乗せるのを同じコマで（メニューが縮んで動いても、カメラは止まっている）。
	for i in 120:
		await get_tree().process_frame
	if not _scene.press_menu(&"attack"):
		return false
	_scene.hover(foe.cell)
	return _scene.forecast_text() != ""


func _scene_forecast_heal() -> bool:
	var healer := func() -> Unit:
		for unit in _own_units():
			if _battle.can_act(unit) and not Queries.heal_targets(_battle, unit).is_empty():
				return unit
		return null
	if not _advance(func() -> bool: return _battle.phase != Unit.Side.NEUTRAL and healer.call() != null):
		return false
	_show()
	var unit: Unit = healer.call()
	var target: Unit = Queries.heal_targets(_battle, unit)[0]
	_scene.click_cell(unit.cell)
	_look_at(BoardView.cell_center(target.cell))
	_scene.hover(target.cell)
	return _scene.forecast_text() != ""


func _scene_battle_unit_detail() -> bool:
	# 傷ついていて、経験値も入っている、人の軍の駒。
	var hurt := func() -> Unit:
		for unit in _own_units():
			if unit.hp < unit.max_hp() and unit.experience > 0 and Skills.of(unit) != null:
				return unit
		return null
	if not _advance(func() -> bool: return hurt.call() != null):
		return false
	_show()
	var unit: Unit = hurt.call()
	_look_at(BoardView.cell_center(unit.cell))
	_scene.click_cell(unit.cell)
	if not _scene.detail_button_shown():
		return false
	_scene.open_unit_detail()
	return _scene.unit_detail().visible


func _scene_info_status() -> bool:
	if not _advance(func() -> bool: return Ults.can_use(_battle)):
		return false
	_show()
	await _scene.act(UseUltAction.new())
	# 装備を持っている駒（無ければ、将でない駒）を見る。
	var best: Unit = null
	for unit in _battle.units:
		if unit.side == _battle.phase and unit.kind != UnitKind.Id.KING and (best == null or unit.equipment.size() > best.equipment.size()):
			best = unit
	if best == null:
		return false
	_look_at(BoardView.cell_center(best.cell))
	_scene.hover(best.cell)
	return not Statuses.types_of(best).is_empty()


func _scene_skill() -> bool:
	var ready := func() -> Unit:
		for unit in _own_units():
			if _battle.can_act(unit) and not Queries.skill_cells(_battle, unit).is_empty():
				return unit
		return null
	if not _advance(func() -> bool: return _battle.turn >= 2 and ready.call() != null):
		return false
	_show()
	var unit: Unit = ready.call()
	_scene.click_cell(unit.cell)
	_scene.press_skill()
	_scene.focus_camera(unit.cell)
	return _scene.is_choosing_skill_target()


func _scene_ult() -> bool:
	if not _advance(func() -> bool: return Ults.can_use(_battle)):
		return false
	_show()
	_scene.press_ult()
	return _scene.is_confirming_ult()


func _scene_end_confirm() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	_scene.press_end_turn()
	return _scene.is_confirming_end()


func _scene_mid_boss() -> bool:
	# 中ボスが倒れたあとの、倒した陣営の番の始め（上の帯に聖遺物が出る）。残っている中ボスを選んで寄せる。
	var slain: Array[MidBossDefeatedEvent] = []
	var watch := func(events: Array[BattleEvent]) -> void:
		for event in events:
			if event is MidBossDefeatedEvent and slain.is_empty():
				slain.append(event)
	if not _advance(func() -> bool: return not slain.is_empty() and _battle.phase == slain[0].slayer_side, watch):
		return false
	_show()
	var focus := slain[0].cell
	for cell in _battle.board.mid_boss_cells:
		var boss := _battle.unit_at(cell)
		if boss != null and boss.side == Unit.Side.NEUTRAL:
			_scene.click_cell(cell)
			focus = cell
	_scene.focus_camera(focus)
	return true


## 決着する行動の手前まで進め、その行動だけを画面に通す（決着の演出と戦績が出る）。hold が 0 以上なら、リザルトの演出をその秒で止める。
## 負ならリザルトの演出を飛ばして、全部を出す。
func _finish_battle(hold: float) -> bool:
	if _advance(func() -> bool: return false):
		return false  # 決着しなかった
	var action := _cpu.next_action(_battle)
	_show()
	_scene.stats = _stats  # 始めからの戦績
	await _scene.act(action)
	if not _battle.is_over():
		return false
	var screen: Control = _scene.result_screen()
	if hold >= 0.0:
		await screen.hold_at(hold)
	else:
		screen.skip()
	return true


func _scene_result_headline() -> bool:
	return await _finish_battle(0.6)


func _scene_result_stats() -> bool:
	return await _finish_battle(1.95)


func _scene_result_mvp() -> bool:
	return await _finish_battle(2.55)


func _scene_result() -> bool:
	return await _finish_battle(-1.0)


func _scene_result_detail() -> bool:
	if not await _finish_battle(-1.0):
		return false
	_scene.result_screen().toggle_detail()
	return true


## CPU 戦のリザルト。won なら人が勝った側（VICTORY）、そうでなければ負けた側（DEFEAT）を人として出し直す。
func _cpu_result(won: bool) -> bool:
	if not await _finish_battle(-1.0):
		return false
	var screen: Control = _scene.result_screen()
	var human := _battle.winner as Unit.Side if won else (1 - _battle.winner) as Unit.Side
	var names: Array[String] = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		names.append(Names.side(side) if side == human else Text.t("battle.side_cpu", {"color": Names.side_word(side)}))
	var reason: String = screen.shown_summary().reason  # 人どうしの理由（決着の理由だけ）
	var summary: RefCounted = ResultSummary.of(_stats, false, _battle.winner, reason, true, human, names, VersusFields.title_of(_field))
	screen.present(summary)
	screen.skip()
	return true


func _scene_result_victory() -> bool:
	return await _cpu_result(true)


func _scene_result_defeat() -> bool:
	return await _cpu_result(false)


## 相手（CPU）の番と中立のフェーズのあと（ターン 5 の自分の番の始め）。始めからのログを画面に渡す。
func _after_cpu_turn() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 5 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	_scene.battle_log = _log
	return true


func _scene_log_closed() -> bool:
	return _after_cpu_turn()


func _scene_log_open() -> bool:
	if not _after_cpu_turn():
		return false
	_scene.open_log()
	return true


func _scene_log_chosen() -> bool:
	if not _after_cpu_turn():
		return false
	_scene.open_log()
	# 相手の番の、いちばん最後の攻撃の行を押す。
	for i in range(_log.entries.size() - 1, -1, -1):
		var entry: BattleLog.Entry = _log.entries[i]
		if entry.phase == Unit.Side.PLAYER2 and entry.text.contains("を攻撃"):
			_scene.log_panel().choose(i)
			return true
	return false


func _scene_log_long() -> bool:
	if _advance(func() -> bool: return false):
		return false  # 決着しなかった
	_show()
	_scene.battle_log = _log
	var started := Time.get_ticks_usec()
	_scene.open_log()
	print("screenshots: ログ %d 行（ターン %d）を %.1f ms で並べた" % [_log.entries.size(), _battle.turn, (Time.get_ticks_usec() - started) / 1000.0])
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: Node = _scene.log_panel()
	panel.scroll_to(panel.scroll_max() - 1500)
	return true


## kinds のどれかの駒が、動かずに攻撃できる場面まで進め、その攻撃を始めて、当たる瞬間から after 秒あとに撮る
## （負なら、当たる前）。カメラは寄せて、相手を真ん中に置く。
func _attack_frame(kinds: Array, after: float) -> bool:
	var find := func() -> Array:
		if _battle.phase == Unit.Side.NEUTRAL:
			return []
		for unit in _own_units():
			if kinds.has(unit.kind) and _battle.can_act(unit):
				var targets := _battle.options(unit.id).attack_target_ids
				if not targets.is_empty():
					return [unit, _battle.unit_by_id(targets[0])]
		return []
	if not _advance(func() -> bool: return not find.call().is_empty()):
		return false
	var found: Array = find.call()
	var unit: Unit = found[0]
	var target: Unit = found[1]
	_show()
	await _settle_camera(target.cell)
	_park_mouse()
	_scene.set_time_scale_base(SLOW_MOTION)
	_scene.act(AttackAction.new(unit.id, target.id))
	await get_tree().create_timer(0.4 + after).timeout  # 0.4 は、攻撃の動きを始めてから当たるまで（unit_view.gd の play_attack）
	_mid_animation = true
	return true


## 番の知らせが消え、カメラが cell に寄り終わるまで待つ（演出の途中を撮る場面の下ごしらえ）。
func _settle_camera(cell: Vector2i) -> void:
	_aim(13.0, 20.0, OrbitCamera.DEFAULT_PITCH)
	_scene.focus_camera(cell)
	await get_tree().create_timer(SETTLE).timeout
	await _banner_gone()


func _scene_hit_slam() -> bool:
	return await _attack_frame([UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.PALADIN], 0.08)


func _scene_hit_slash() -> bool:
	return await _attack_frame([UnitKind.Id.COMMANDO, UnitKind.Id.SPELLBLADE], 0.08)


func _scene_hit_shot() -> bool:
	return await _attack_frame([UnitKind.Id.SNIPER], 0.06)


func _scene_hit_magic() -> bool:
	return await _attack_frame([UnitKind.Id.SORCERER], -0.07)


func _scene_auto_confirm() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 2 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	await _idle()
	_scene.press_auto()
	return _scene.is_confirming_auto()


func _scene_cpu_watch() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 2 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	await _idle()
	_scene.set_opponent(true)
	_park_mouse()
	_scene.set_time_scale_base(SLOW_MOTION)
	_scene.press_end_turn()
	_scene.pass_confirm_guard()
	_scene.press_end_turn()
	await get_tree().create_timer(0.4).timeout
	_mid_animation = true
	return _scene.watch_controls_state()[0]


func _scene_wait_sign() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 2 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	var unit: Unit = null
	for candidate in _own_units():
		if _battle.can_act(candidate) and candidate.kind != UnitKind.Id.KING:
			unit = candidate
			break
	if unit == null:
		return false
	await _settle_camera(unit.cell)
	_park_mouse()
	_scene.set_time_scale_base(SLOW_MOTION)
	_scene.act(WaitAction.new(unit.id))
	await get_tree().create_timer(0.15).timeout
	_mid_animation = true
	return true


## skill を持つ駒が使える場面まで進め、使って、使った瞬間から after 秒あとに撮る。
## 対象は、駒のいるマス（自分のほか）を優先する。カメラは対象へ寄せる。
func _skill_frame(skill: Skill.Id, after: float) -> bool:
	var find := func() -> Array:
		if _battle.phase == Unit.Side.NEUTRAL:
			return []
		for unit in _own_units():
			if Skills.of(unit) == null or Skills.of(unit).id() != skill or not _battle.can_act(unit):
				continue
			var cells := Queries.skill_cells(_battle, unit)
			if cells.is_empty():
				continue
			for cell in cells:
				if cell != unit.cell and _battle.unit_at(cell) != null:
					return [unit, cell]
			return [unit, cells[0]]
		return []
	if not _advance(func() -> bool: return not find.call().is_empty()):
		return false
	var found: Array = find.call()
	var unit: Unit = found[0]
	_show()
	await _settle_camera((unit.cell + found[1]) / 2)
	_park_mouse()
	_scene.set_time_scale_base(SLOW_MOTION)
	_scene.act(UseSkillAction.new(unit.id, found[1]))
	await get_tree().create_timer(after).timeout
	_mid_animation = true
	return true


func _scene_skill_fireball() -> bool:
	return await _skill_frame(Skill.Id.FIREBALL, 0.43)


func _scene_skill_barricade() -> bool:
	return await _skill_frame(Skill.Id.TACTICAL_BARRICADE, 0.47)


func _scene_skill_smoke() -> bool:
	return await _skill_frame(Skill.Id.SMOKE_GRENADE, 0.5)


func _scene_skill_saint() -> bool:
	return await _skill_frame(Skill.Id.SAINT_PLACE, 0.5)


func _scene_skill_shield() -> bool:
	return await _skill_frame(Skill.Id.DIVINE_SHIELD, 0.5)


func _scene_skill_aim() -> bool:
	return await _skill_frame(Skill.Id.PRECISION_AIM, 0.55)


func _scene_skill_shadow() -> bool:
	return await _skill_frame(Skill.Id.SHADOW_STEP, 0.48)


func _scene_skill_adrenaline() -> bool:
	return await _skill_frame(Skill.Id.ADRENALINE_SHOT, 0.58)


## army の必殺技が使える場面まで進め、使って、使った瞬間から after 秒あとに撮る。
func _ult_frame(army: UnitKind.Army, after: float) -> bool:
	var ready := func() -> bool:
		return Ults.can_use(_battle) and Ults.of(_battle, _battle.phase) != null and Ults.of(_battle, _battle.phase).army() == army
	if not _advance(ready):
		return false
	_show()
	# 効果の掛かる駒（いまの番の陣営の駒）が、いちばん多く集まっているところを見る。
	var units := _own_units()
	var best := units[0].cell
	var best_count := -1
	for unit in units:
		var count := 0
		for other in units:
			if _distance(unit.cell, other.cell) <= 4:
				count += 1
		if count > best_count:
			best = unit.cell
			best_count = count
	_aim(17.0, 0.0, OrbitCamera.DEFAULT_PITCH)
	_scene.focus_camera(best)
	await get_tree().create_timer(SETTLE).timeout
	await _banner_gone()
	_park_mouse()
	_scene.set_time_scale_base(SLOW_MOTION)
	_scene.act(UseUltAction.new())
	await get_tree().create_timer(after).timeout
	_mid_animation = true
	return true


func _scene_ult_assault() -> bool:
	return await _ult_frame(UnitKind.Army.MILITARY, 0.1)


func _scene_ult_eruption() -> bool:
	return await _ult_frame(UnitKind.Army.FANTASY, 0.62)


func _scene_wide() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	_look_at(Vector3(_battle.board.size.x / 2.0, 0.0, _battle.board.size.y / 2.0 + 6.0))
	_aim(45.0, 0.0, OrbitCamera.MIN_PITCH)
	return true


func _scene_board_edge() -> bool:
	_show()
	# 盤の左上の角の近くに立って、角の外へ向く。
	_look_at(Vector3(1.5, 0.0, 1.5))
	_aim(26.0, -40.0, 35.0)
	return true


func _scene_rotated() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	_look_at(_scene.camera_center())
	_aim(30.0, 130.0, 35.0)
	return true


func _scene_marks() -> bool:
	# 行動済みの駒と、HP の減った駒が並ぶところ: 番の途中で、HP の減った自分の駒がまだ動けるとき。
	var hurt := func() -> Unit:
		for unit in _own_units():
			if unit.hp < unit.max_hp() and _battle.can_act(unit) and unit.kind != UnitKind.Id.KING:
				return unit
		return null
	var acted := func() -> bool:
		for unit in _own_units():
			if not _battle.can_act(unit):
				return true
		return false
	if not _advance(func() -> bool: return _battle.phase == Unit.Side.PLAYER1 and acted.call() and hurt.call() != null):
		return false
	_show()
	var unit: Unit = hurt.call()
	_scene.click_cell(unit.cell)
	_look_at(Vector3(unit.cell.x + 0.5, 0.0, unit.cell.y + 0.5))
	_aim(11.0, 0.0, 50.0)
	return true


func _scene_stage_labyrinth() -> bool:
	return _stage_overview(BoardGenerator.Stage.LABYRINTH)


func _scene_stage_twin_springs() -> bool:
	return _stage_overview(BoardGenerator.Stage.TWIN_SPRINGS)


## マップの見た目を比べる 3 枚（始め・引いた・寄った）。どのマップも同じ構図で撮る。
func _stage_look(stage: BoardGenerator.Stage, view: StringName) -> bool:
	_field = VersusFields.field_of_stage(stage)
	_new_battle()
	_show()
	var middle := Vector3(_battle.board.size.x / 2.0, 0.0, _battle.board.size.y / 2.0)
	match view:
		&"wide":
			_look_at(middle + Vector3(0.0, 0.0, 6.0))
			_aim(45.0, 0.0, OrbitCamera.MIN_PITCH)
		&"close":
			_look_at(middle)
			_aim(12.0, 20.0, 45.0)
		&"crag":
			_look_at(middle)
			_aim(22.0, 140.0, 42.0)
		&"crag_low":
			_look_at(middle + Vector3(0.0, 0.0, 5.0))
			_aim(16.0, 0.0, OrbitCamera.MIN_PITCH)
	return true


func _scene_look_plain_start() -> bool:
	return _stage_look(BoardGenerator.Stage.PLAIN, &"start")


func _scene_look_plain_wide() -> bool:
	return _stage_look(BoardGenerator.Stage.PLAIN, &"wide")


func _scene_look_plain_close() -> bool:
	return _stage_look(BoardGenerator.Stage.PLAIN, &"close")


func _scene_look_labyrinth_start() -> bool:
	return _stage_look(BoardGenerator.Stage.LABYRINTH, &"start")


func _scene_look_labyrinth_wide() -> bool:
	return _stage_look(BoardGenerator.Stage.LABYRINTH, &"wide")


func _scene_look_labyrinth_close() -> bool:
	return _stage_look(BoardGenerator.Stage.LABYRINTH, &"close")


func _scene_look_twin_springs_start() -> bool:
	return _stage_look(BoardGenerator.Stage.TWIN_SPRINGS, &"start")


func _scene_look_twin_springs_wide() -> bool:
	return _stage_look(BoardGenerator.Stage.TWIN_SPRINGS, &"wide")


func _scene_look_twin_springs_close() -> bool:
	return _stage_look(BoardGenerator.Stage.TWIN_SPRINGS, &"close")


func _scene_look_boulder_crag() -> bool:
	_field = VersusFields.BOULDER_PASS
	_new_battle()
	_show()
	_look_at(Vector3(_battle.board.size.x / 2.0, 0.0, _battle.board.size.y / 2.0))
	_aim(20.0, 140.0, 42.0)
	return true


func _scene_look_twin_springs_crag() -> bool:
	return _stage_look(BoardGenerator.Stage.TWIN_SPRINGS, &"crag")


func _scene_look_twin_springs_crag_low() -> bool:
	return _stage_look(BoardGenerator.Stage.TWIN_SPRINGS, &"crag_low")


## stage の盤で、cells の最初のマスへ寄って見る（泉・ポータルの動き）。
func _close_look(stage: BoardGenerator.Stage, cells: Callable) -> bool:
	_field = VersusFields.field_of_stage(stage)
	_new_battle()
	_show()
	var found: Array = cells.call(_battle.board)
	if found.is_empty():
		return false
	_scene.focus_camera(found[0])
	_aim(7.0, 20.0, 48.0)
	return true


func _scene_spring() -> bool:
	return _close_look(BoardGenerator.Stage.LABYRINTH, func(board: Board) -> Array: return board.spring_cells)


func _scene_portal() -> bool:
	return _close_look(BoardGenerator.Stage.TWIN_SPRINGS, func(board: Board) -> Array: return board.portal_exits.keys())


## 作戦（試しの決まり）の手札のボタンが出ている対戦。1 枚目を 1 回押して、確かめているところ。
func _scene_tactic() -> bool:
	_field = VersusFields.PLAIN
	_new_battle([TrialRules.TACTICS])
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	if _scene.tactic_buttons().is_empty() or not _scene.tactic_buttons()[0][1]:
		return false
	_scene.press_tactic(0)
	return true


## 強行軍を使った直後。広がった移動の範囲を塗っている間を撮る。
func _scene_tactic_march() -> bool:
	_field = VersusFields.PLAIN
	_new_battle([TrialRules.TACTICS])
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	var index := Tactics.hand(_battle, Unit.Side.PLAYER1).find(Tactics.Id.MARCH)
	if index < 0 or not Tactics.is_unused(_battle, Unit.Side.PLAYER1, Tactics.Id.MARCH):
		return false
	var front := _battle.board.hq_cells[Unit.Side.PLAYER1]
	for unit in _battle.units:
		if unit.side == Unit.Side.PLAYER1 and unit.kind != UnitKind.Id.KING and not unit.acted:
			front = unit.cell
			break
	await _settle_camera(front)
	_park_mouse()
	_scene.press_tactic(index)
	_scene.pass_confirm_guard()
	_scene.set_time_scale_base(0.5)
	_scene.press_tactic(index)
	await get_tree().create_timer(1.3).timeout  # 知らせと、駒ごとの「移動 +2」のあと、範囲を塗っている間（対戦の時間で数える）
	_mid_animation = true
	return true


## 試しの決まりを全部入にした対戦の始め。
func _scene_trial_notice() -> bool:
	_field = VersusFields.PLAIN
	_new_battle(TrialRules.ALL.duplicate())
	_show()
	return _scene.notice_text() != ""


func _scene_battery_cell() -> bool:
	_field = VersusFields.PLAIN
	_new_battle([TrialRules.BATTERY])
	_show()
	var batteries := _battle.board.battery_cells
	if batteries.is_empty():
		return false
	_scene.click_cell(batteries[0])
	_scene.focus_camera(batteries[0])
	return _scene.info_title().begins_with("マス")


## 砲台に後衛が乗っている番の始めまで進め、その駒を選ぶ（伸びた射程が、移動範囲の外の攻撃範囲に出る）。
func _scene_battery() -> bool:
	_field = VersusFields.PLAIN
	_new_battle([TrialRules.BATTERY])
	var gunner: Array[Unit] = []
	if not _advance(func() -> bool:
		gunner.clear()
		for unit in _battle.units:
			if unit.site_range > 0 and unit.side == _battle.phase and _battle.can_act(unit):
				gunner.append(unit)
		return not gunner.is_empty()
	):
		return false
	_show()
	_scene.click_cell(gunner[0].cell)
	_scene.focus_camera(gunner[0].cell)
	return true


func _scene_stronghold_cell() -> bool:
	_field = VersusFields.PLAIN
	_new_battle([TrialRules.STRONGHOLD])
	_show()
	var cell := _battle.board.stronghold_cell
	if cell == Board.NO_CELL:
		return false
	_scene.click_cell(cell)
	_scene.focus_camera(cell)
	return _scene.info_title().begins_with("マス")


func _scene_stronghold_hover() -> bool:
	_field = VersusFields.PLAIN
	_new_battle([TrialRules.STRONGHOLD])
	_show()
	var cell := _battle.board.stronghold_cell
	if cell == Board.NO_CELL:
		return false
	_scene.focus_camera(cell)
	_scene.hover(cell)
	return true


## どちらかが、あと 1 回の確保で勝つところまで進める（拠点に駒が乗り、旗がその陣営の色。上の帯の札が目立つ）。
func _scene_stronghold() -> bool:
	_field = VersusFields.LABYRINTH
	_new_battle([TrialRules.STRONGHOLD])
	if not _advance(func() -> bool:
		return Stronghold.holds_left(_battle, Unit.Side.PLAYER1) == 1 or Stronghold.holds_left(_battle, Unit.Side.PLAYER2) == 1
	):
		return false
	_show()
	_scene.focus_camera(_battle.board.stronghold_cell)
	return true


func _scene_portal_cell() -> bool:
	_field = VersusFields.TWIN_SPRINGS
	_new_battle()
	_show()
	var portals: Array = _battle.board.portal_exits.keys()
	if portals.is_empty():
		return false
	_scene.click_cell(portals[0])
	_scene.focus_camera(portals[0])
	return _scene.info_title().begins_with("マス")


## いまの番の駒のうち、歩いてポータルに止まれて、そこから転移できる駒と、そのポータル（[駒, マス]）。無ければ空。
func _portal_walker() -> Array:
	for unit in _own_units():
		if not _battle.can_act(unit):
			continue
		var portals := Queries.reachable_portals(_battle, unit)
		for portal: Vector2i in portals:
			if portal != unit.cell and not Queries.move_cells(_battle, unit)[portal]:
				return [unit, portal]
	return []


func _scene_portal_range() -> bool:
	_field = VersusFields.TWIN_SPRINGS
	_new_battle()
	if not _advance(func() -> bool: return _battle.phase == Unit.Side.PLAYER1 and not _portal_walker().is_empty()):
		return false
	_show()
	var found := _portal_walker()
	var unit: Unit = found[0]
	var portal: Vector2i = found[1]
	_scene.click_cell(unit.cell)
	_look_at(BoardView.cell_center(portal) + (BoardView.cell_center(_battle.portal_exit(portal)) - BoardView.cell_center(portal)) * 0.4)
	_aim(44.0, 0.0, 72.0)
	_scene.hover(portal)
	return _scene.painted_color(_battle.portal_exit(portal)) == _scene.portal_paint_color(portal)


func _scene_portal_menu() -> bool:
	_field = VersusFields.TWIN_SPRINGS
	_new_battle()
	if not _advance(func() -> bool: return _battle.phase == Unit.Side.PLAYER1 and not _portal_walker().is_empty()):
		return false
	_show()
	var found := _portal_walker()
	var unit: Unit = found[0]
	var portal: Vector2i = found[1]
	await _idle()
	_scene.click_cell(unit.cell)
	_scene.click_cell(portal)
	await _idle()
	_look_at(BoardView.cell_center(portal) + (BoardView.cell_center(_battle.portal_exit(portal)) - BoardView.cell_center(portal)) * 0.4)
	_aim(44.0, 0.0, 72.0)
	return unit.cell == portal and _scene.menu_ids().has(&"warp")


func _scene_portal_warped() -> bool:
	_field = VersusFields.TWIN_SPRINGS
	_new_battle()
	if not _advance(func() -> bool: return _battle.phase == Unit.Side.PLAYER1 and not _portal_walker().is_empty()):
		return false
	_show()
	var found := _portal_walker()
	var unit: Unit = found[0]
	var portal: Vector2i = found[1]
	var exit := _battle.portal_exit(portal)
	await _idle()
	_scene.click_cell(unit.cell)
	_scene.click_cell(portal)
	await _idle()
	_scene.press_warp()
	await _idle()
	_look_at(BoardView.cell_center(exit))
	_aim(44.0, 0.0, 60.0)
	return unit.cell == exit and not Queries.move_cells(_battle, unit).is_empty()


func _stage_overview(stage: BoardGenerator.Stage) -> bool:
	_field = VersusFields.field_of_stage(stage)
	_new_battle()
	_show()
	_look_at(Vector3(_battle.board.size.x / 2.0, 0.0, _battle.board.size.y / 2.0 + 1.0))
	_aim(45.0, 0.0, 68.0)
	return true


# ---- 場面を作る道具 ----


# ---- ストーリー ----


const Story := preload("res://game/story.gd")
const Run := preload("res://game/run.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const BattleCues := preload("res://game/battle_cues.gd")


## タイトルの「ストーリー」で話の一覧へ進み、number 番目（0 から）の話を始める（出撃準備の場面に入る）。
## 前の話は、クリアしたことにする。number が負なら、部隊を選ぶ最初の話（チュートリアルのあとの本編の 1 話目）。
func _start_story(number := -1) -> bool:
	if number < 0:
		number = _main_episode()
	_app.context.story.choose_campaign(Story.military())  # クリアは、いま選んでいる物語の記録に書く（前の場面が FANTASY を選んでいても）
	for i in number:
		_app.context.story.clear(Story.military().episodes[i].id)
	if not await _scene_story_list():
		return false
	_app.current_scene().choose(Story.military().episodes[number])
	await _app.scene_changed
	return _app.current_id() == SceneFlow.SORTIE


## タイトルの「ストーリー」のあとの、物語を選ぶ場面（話の無い物語は準備中）。セーブデータ選択は、いまのスロットで通る。
func _scene_story_campaigns() -> bool:
	await _app.go(SceneFlow.TITLE)
	_app.current_scene().press_story()
	await _app.scene_changed
	if _app.current_id() != SceneFlow.SLOTS:
		return false
	_app.current_scene().choose(_app.context.slots.current)
	await _app.scene_changed
	return _app.current_id() == SceneFlow.CAMPAIGNS


## 物語を選ぶ場面で、物語 index のカードを、キーで選んだところ（背景がその物語の景色に替わる）。
func _campaign_focused(index: int) -> bool:
	if not await _scene_story_campaigns():
		return false
	_app.current_scene().select_by_key(index)
	_app.current_scene().backdrop().swap_now()
	return true


func _scene_story_campaigns_berg() -> bool:
	return await _campaign_focused(0)


func _scene_story_campaigns_ruel() -> bool:
	return await _campaign_focused(1)


func _scene_story_slots_fantasy() -> bool:
	if not await _scene_story_slots():
		return false
	_app.current_scene().select_by_key(1)
	_app.current_scene().backdrop().swap_now()
	return true


## セーブデータ選択: 1 番は MILITARY の物語を 7 話まで、2 番は FANTASY の物語を 3 話まで、3 番は空き。
func _scene_story_slots() -> bool:
	var context: RefCounted = _app.context
	var plans := [[Story.military(), 7, 9000], [_fantasy(), 3, 2700]]
	for i in plans.size():
		context.use_slot(i + 1)
		context.story.choose_campaign(plans[i][0])
		for episode: RefCounted in (plans[i][0].episodes as Array).slice(0, plans[i][1]):
			context.story.clear(episode.id)
		context.slots._played = float(plans[i][2])
		context.slots.flush()
	context.use_slot(1)
	await _app.go(SceneFlow.TITLE)
	_app.current_scene().press_story()
	await _app.scene_changed
	return _app.current_id() == SceneFlow.SLOTS


## セーブデータ選択で、コピー先を選んでいるところ。
func _scene_story_slots_copy() -> bool:
	if not await _scene_story_slots():
		return false
	_app.current_scene().press_copy(1)
	return _app.current_scene().is_copying()


## セーブデータ選択で、削除を確かめているところ。
func _scene_story_slots_delete() -> bool:
	if not await _scene_story_slots():
		return false
	_app.current_scene().press_delete(2)
	return _app.current_scene().confirm_window().is_open()


func _scene_story_list() -> bool:
	if not await _scene_story_campaigns():
		return false
	_app.current_scene().choose(Story.military())
	await _app.scene_changed
	return _app.current_id() == SceneFlow.EPISODES


func _scene_story_open_all() -> bool:
	if not await _scene_story_list():
		return false
	_app.open_all_key().toggle()
	await _app.scene_changed
	return _app.current_id() == SceneFlow.EPISODES and _app.context.story.open_all


## 2 つ目の物語（FANTASY の物語）。
func _fantasy() -> RefCounted:
	return Story.campaigns()[1]


## FANTASY の物語の話の一覧（何もクリアしていない。頭の演習）。
func _scene_story_fantasy_list() -> bool:
	if not await _scene_story_campaigns():
		return false
	_app.current_scene().choose(_fantasy())
	await _app.scene_changed
	return _app.current_id() == SceneFlow.EPISODES


## FANTASY の物語の演習（第 2 話）の出撃準備: この話で覚えること、決まっている部隊。
func _scene_story_fantasy_sortie() -> bool:
	_app.context.story.choose_campaign(_fantasy())  # クリアは、いま選んでいる物語の記録に書く
	_app.context.story.clear(_fantasy().episodes[0].id)
	if not await _scene_story_fantasy_list():
		return false
	_app.current_scene().choose(_fantasy().episodes[1])
	await _app.scene_changed
	if not _at_sortie():
		return false
	return _app.current_scene().is_squad_fixed()


## FANTASY の物語の number 番目（0 から。負なら最後）の話を始める（出撃準備の場面に入る）。前の話は、クリアしたことにする。
func _start_fantasy(number: int) -> bool:
	var episodes: Array = _fantasy().episodes
	if number < 0:
		number = episodes.size() - 1
	_app.context.story.choose_campaign(_fantasy())  # クリアは、いま選んでいる物語の記録に書く
	for i: int in number:
		_app.context.story.clear(episodes[i].id)
	if not await _scene_story_fantasy_list():
		return false
	_app.current_scene().choose(episodes[number])
	await _app.scene_changed
	return _app.current_id() == SceneFlow.SORTIE


func _scene_story_fantasy_evolve_sortie() -> bool:
	var number := -1
	for i: int in _fantasy().episodes.size():
		if _fantasy().episodes[i].id == &"trial_evolution":
			number = i
	return number >= 0 and await _start_fantasy(number) and _at_sortie()


## FANTASY の物語の「峠の番人」を、CPU に人の側を持たせて、中ボスの撃破で勝つまで進める。
## 人の側の駒が敵のプレイヤーの駒にダメージを与えていない種だけ（MVP が中ボスへのダメージで決まるところを撮る）。
func _scene_story_boss_mvp() -> bool:
	var number := -1
	for i: int in _fantasy().episodes.size():
		if _fantasy().episodes[i].id == &"boulder_warden":
			number = i
	if number < 0 or not await _start_fantasy(number) or not _at_sortie():
		return false
	if not await _sortie_to_battle():
		return false
	_scene = _app.current_scene()
	var setup: MatchSetup = _scene.source.make_setup(_seed)
	_battle = setup.create_battle()
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "CPU（赤）"] as Array[String])
	if _advance(func() -> bool: return false):
		return false
	var action := _cpu.next_action(_battle)
	if _battle.phase != Unit.Side.PLAYER1 or _stats.sides[Unit.Side.PLAYER1].damage > 0:
		return false
	_scene.start_with(_battle, _scene.source.look(), _seed, setup.scenario.title)
	_scene.stats = _stats
	await _scene.act(action)
	if not _battle.is_over() or _battle.winner != Unit.Side.PLAYER1 or _stats.ending != BattleStats.Ending.BOSS_SLAIN:
		return false
	_scene.result_screen().skip()
	return true


## FANTASY の物語の演習「分かれ道」: あと 1 撃で進化するパラディンを盾役の隣へ動かして攻撃し、進化先の選択を出す。
func _scene_story_fantasy_evolve() -> bool:
	var number := -1
	for i: int in _fantasy().episodes.size():
		if _fantasy().episodes[i].id == &"trial_evolution":
			number = i
	if number < 0 or not await _start_fantasy(number) or not _at_sortie():
		return false
	if not await _sortie_to_battle():
		return false
	_scene = _app.current_scene()
	var paladin: Unit = null
	var guard: Unit = null
	for unit: Unit in _scene.battle.units:
		if unit.kind == UnitKind.Id.PALADIN and unit.side == Unit.Side.PLAYER1:
			paladin = unit
		elif unit.kind == UnitKind.Id.SHIELD_TROOPER:
			guard = unit
	if paladin == null or guard == null:
		return false
	_scene.click_cell(paladin.cell)
	_scene.click_cell(guard.cell + Vector2i(0, 1))
	while _scene.is_busy():
		await get_tree().process_frame
	_scene.press_menu(&"attack")
	_scene.click_cell(guard.cell)
	while _scene.is_busy():
		await get_tree().process_frame
	return _scene.is_choosing_evolution()


## 部隊を選ぶ最初の話（FANTASY の物語の本編の 1 話目）の番号（0 から）。
func _fantasy_main_episode() -> int:
	for i: int in _fantasy().episodes.size():
		if _fantasy().episodes[i].squad_deck() == null:
			return i
	return 0


## FANTASY の物語の本編の 1 話目をクリアしたあとの話の一覧。
func _scene_story_fantasy_main_list() -> bool:
	_app.context.story.choose_campaign(_fantasy())
	for i: int in _fantasy_main_episode() + 1:
		_app.context.story.clear(_fantasy().episodes[i].id)
	return await _scene_story_fantasy_list()


## FANTASY の物語の最後の話の出撃準備（既定の編成）。
## FANTASY の物語の、味方が 2 か所に分かれて始まる話（岩山の合流）の出撃準備。
func _scene_story_split_sortie() -> bool:
	_app.context.decks.load_data({"decks": []})
	var at: int = _fantasy().episodes.map(func(episode: RefCounted) -> StringName: return episode.id).find(&"gorge_rejoin")
	if at < 0 or not await _start_fantasy(at):
		return false
	return _at_sortie()


## 南の置けるマス（盤の下半分）にいる最初の駒を、北の置けるマスの空いているところへ移す。
func _scene_story_split_placed() -> bool:
	if not await _scene_story_split_sortie():
		return false
	var deploy: Control = _app.current_scene().deploy_map()
	var own: Array[Vector2i] = deploy.unit_cells()
	var south: Array = own.filter(func(cell: Vector2i) -> bool: return cell.y > 10)
	var open: Array = deploy.zone().filter(func(cell: Vector2i) -> bool: return cell.y < 10 and not own.has(cell))
	if south.is_empty() or open.is_empty():
		return false
	deploy.press_cell(south[0])
	deploy.press_cell(open[0])
	_park_mouse()
	return deploy.unit_cells().has(open[0])


func _scene_story_split_talk() -> bool:
	if not await _scene_story_split_sortie() or not await _talk_from_sortie():
		return false
	var talk: Node = _app.current_scene()
	return talk.speaker() == "セリス" and talk.figures().size() >= 1


func _scene_story_split_start() -> bool:
	if not await _scene_story_split_sortie() or not await _sortie_to_battle():
		return false
	_scene = _app.current_scene()
	var size: Vector2i = _scene.battle.board.size
	_look_at(Vector3(size.x / 2.0, 0.0, size.y / 2.0))
	_aim(OrbitCamera.max_distance_for(size), 0.0, (OrbitCamera.MIN_PITCH + OrbitCamera.MAX_PITCH) / 2.0)
	_park_mouse()
	return true


## MILITARY の物語の「縫い目の発破」（結晶の採掘場。味方が正面と西の脇に分かれて始まる）の対戦の始めを、いちばん引いて見る。
func _scene_story_quarry_start() -> bool:
	_app.context.decks.load_data({"decks": []})
	if not await _start_story(_military_index(&"quarry_blast")) or not await _sortie_to_battle():
		return false
	_scene = _app.current_scene()
	var size: Vector2i = _scene.battle.board.size
	_look_at(Vector3(size.x / 2.0, 0.0, size.y / 2.0))
	_aim(OrbitCamera.max_distance_for(size), 0.0, (OrbitCamera.MIN_PITCH + OrbitCamera.MAX_PITCH) / 2.0)
	_park_mouse()
	return true


func _scene_story_fantasy_forest_sortie() -> bool:
	_app.context.decks.load_data({"decks": []})
	if not await _start_fantasy(_fantasy_index(&"mist_forest")):
		return false
	return _at_sortie()


## FANTASY の物語の話の番号（0 から）。無ければ最後の話。
func _fantasy_index(id: StringName) -> int:
	var episodes: Array = _fantasy().episodes
	var at := episodes.map(func(episode: RefCounted) -> StringName: return episode.id).find(id)
	return at if at >= 0 else episodes.size() - 1


## FANTASY の物語の最後の話「墓守の眠り」（縫い目の谷）の対戦の始めを、いちばん引いて見る。
func _scene_story_vale_start() -> bool:
	_app.context.decks.load_data({"decks": []})
	if not await _start_fantasy(_fantasy_index(&"vale_keeper")) or not await _sortie_to_battle():
		return false
	_scene = _app.current_scene()
	var size: Vector2i = _scene.battle.board.size
	_look_at(Vector3(size.x / 2.0, 0.0, size.y / 2.0))
	_aim(OrbitCamera.max_distance_for(size), 0.0, (OrbitCamera.MIN_PITCH + OrbitCamera.MAX_PITCH) / 2.0)
	_park_mouse()
	return true


## FANTASY の物語の最後の話の対戦の始めを、いちばん引いて見る。
func _scene_story_fantasy_forest_wide() -> bool:
	if not await _scene_story_fantasy_forest_sortie():
		return false
	if not await _sortie_to_battle():
		return false
	_scene = _app.current_scene()
	var size: Vector2i = _scene.battle.board.size
	_look_at(Vector3(size.x / 2.0, 0.0, size.y / 2.0))
	_aim(OrbitCamera.max_distance_for(size), 0.0, OrbitCamera.MIN_PITCH)
	return true


## 部隊編成の「ストーリー用」を FANTASY の物語に切り替えて、最初から雇える駒で組む。
func _scene_story_fantasy_decks() -> bool:
	await _app.go(SceneFlow.DECKS)
	var screen: Node = _app.current_scene()
	screen.set_mode(_fantasy().rules_id)
	screen.press_new()
	for kind: UnitKind.Id in _fantasy().starting_kinds:
		screen.hire(kind)
	return screen.editing_deck().army == _fantasy().army and not screen.editing_deck().entries.is_empty()


## 部隊を選ぶ最初の話（部隊が決まっていない最初の話。チュートリアルのあとの本編の 1 話目）の番号（0 から）。
func _main_episode() -> int:
	for i in Story.military().episodes.size():
		if Story.military().episodes[i].squad_deck() == null:
			return i
	return 0


## 本編の 1 話目をクリアしたあとの話の一覧（次の話が選べる。いま雇える駒が増えた）。
func _scene_story_list_cleared() -> bool:
	for i in _main_episode() + 1:
		_app.context.story.clear(Story.military().episodes[i].id)
	return await _scene_story_list()


## 何もクリアしていない話の一覧（頭のチュートリアルの話。番号に「（演習）」）。
func _scene_story_tutorial_list() -> bool:
	return await _scene_story_list()


## チュートリアルの話（第 2 話「撃ち合い」）の出撃準備: この話で覚えること、決まっている部隊。
func _scene_story_tutorial_sortie() -> bool:
	if not await _start_story(1):
		return false
	if not _at_sortie():
		return false
	return _app.current_scene().is_squad_fixed()


func _scene_story_talk_log() -> bool:
	if not await _start_story() or not await _talk_from_sortie():
		return false
	var talk: Node = _app.current_scene()
	while talk.line_index() < talk.line_count() - 1:
		talk.press_next()
	talk.open_log()
	await get_tree().process_frame
	await get_tree().process_frame
	return talk.talk_log().is_open()


func _scene_story_talk() -> bool:
	if not await _start_story() or not await _talk_from_sortie():
		return false
	return _talk_until(1)


## いまの会話を、陣営 side の、at 人目（0 から。同じ人は 1 度だけ数える）の話し手が話す文まで送る。その人が出てこなければ偽。
func _talk_until(side: int, at := 0) -> bool:
	var talk: Node = _app.current_scene()
	var lines: Array = talk.talk["lines"]
	var seen := []
	for index in lines.size():
		var who: int = lines[index].get("who", -1)
		if int(lines[index]["side"]) != side or seen.has(who):
			continue
		seen.append(who)
		if seen.size() == at + 1:
			while talk.line_index() < index:
				talk.press_next()
			return true
	return false


## 話 id の、MILITARY の物語の中の番号（0 から）。
func _military_index(id: StringName) -> int:
	var episodes: Array = Story.military().episodes
	for index in episodes.size():
		if episodes[index].id == id:
			return index
	return -1


## 地の文（話し手のいない行）。「尾根の小道」の前の会話は、地の文から始まる。
func _scene_story_talk_narration() -> bool:
	if not await _start_story(_military_index(&"ridge_path")) or not await _talk_from_sortie():
		return false
	return _app.current_scene().is_narrating()


## ハーデンとイェルダが向き合う会話（MILITARY の物語）。ハーデンが話していて、右にイェルダ。
func _scene_story_rivals_ridge() -> bool:
	if not await _start_story(_military_index(&"ridge_path")) or not await _talk_from_sortie():
		return false
	return _talk_until(0) and _app.current_scene().figures().size() == 2


## ハーデンとイェルダが向き合う会話（FANTASY の物語の「森の守り」）。イェルダが話していて、右にハーデン。
func _scene_story_rivals_forest() -> bool:
	var episodes: Array = _fantasy().episodes
	var at := episodes.map(func(episode: RefCounted) -> StringName: return episode.id).find(&"mist_forest")
	if at < 0 or not await _start_fantasy(at) or not await _talk_from_sortie():
		return false
	var talk: Node = _app.current_scene()
	while talk.line_index() < talk.line_count() and talk.speaker() != "イェルダ":
		talk.press_next()
	return talk.speaker() == "イェルダ" and talk.figures().size() == 2


## 部隊の中の人（人の軍の 3 人目の話し手）が話している、対戦の前の会話。右に敵の話し手。
func _scene_story_talk_squad() -> bool:
	if not await _start_story(_military_index(&"gorge_rout")) or not await _talk_from_sortie():
		return false
	return _talk_until(0, 2) and _app.current_scene().figures().size() == 2


## 敵の軍が出てこない会話。人の軍の 2 人目の話し手が、右に立って話している。
func _scene_story_talk_allies() -> bool:
	if not await _start_story(_military_index(&"drill_medic")) or not await _talk_from_sortie():
		return false
	var talk: Node = _app.current_scene()
	return _talk_until(0, 1) and talk.figures().size() == 2 and talk.figures().all(func(view: Control) -> bool: return view.side == 0)


func _scene_story_talk_drill() -> bool:
	return await _start_story(0) and await _talk_from_sortie()


func _scene_story_fantasy_talk() -> bool:
	return await _start_fantasy(0) and await _talk_from_sortie()


func _scene_story_talk_menu() -> bool:
	if not await _scene_story_talk():
		return false
	_app.open_menu()
	return _app.system_menu().is_open()


## 出撃して、前の会話を飛ばして、話の対戦の場面に入る。
func _story_battle(number := -1) -> bool:
	if not await _start_story(number):
		return false
	if not _at_sortie():
		return false
	if not await _sortie_to_battle():
		return false
	_scene = _app.current_scene()
	return true


## 話を始めて、出撃準備の場面に入る。
func _at_sortie() -> bool:
	return _app.current_id() == SceneFlow.SORTIE


## 出撃準備の「出撃」で、対戦の前の会話の場面に入る。
func _talk_from_sortie() -> bool:
	if not _at_sortie():
		return false
	_app.current_scene().press_sortie()
	await _app.scene_changed
	return _app.current_id() == SceneFlow.TALK


## 出撃準備の「出撃」のあと、対戦の前の会話を飛ばして、話の対戦の場面に入る（会話を通り過ぎていれば、そのまま対戦へ）。
func _sortie_to_battle() -> bool:
	_app.current_scene().press_sortie()
	await _app.scene_changed
	if _app.current_id() == SceneFlow.TALK:
		_app.current_scene().press_skip()
		await _app.scene_changed
	return _app.current_id() == SceneFlow.BATTLE


## 出撃準備（ストーリー用の部隊を 1 つ取っておいて、それを選んだところ）。
func _scene_story_sortie() -> bool:
	_app.context.decks.load_data({"decks": []})
	var deck := Deck.new(Story.military().army, _app.context.story.deck_rules())
	for kind: UnitKind.Id in [UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SNIPER, UnitKind.Id.SNIPER, UnitKind.Id.MEDIC]:
		deck.add(kind)
	var saved: RefCounted = _app.context.decks.add("狙撃の小隊", deck)
	if not await _start_story():
		return false
	if not _at_sortie():
		return false
	_app.current_scene().choose(saved.id)
	return _app.current_scene().chosen_id() == saved.id


## 全部の話をクリアして、部隊編成の「ストーリー用」で、解放した駒（コマンドー）を雇う。
func _scene_story_unlocked_decks() -> bool:
	for episode in Story.military().episodes:
		_app.context.story.clear(episode.id)
	await _app.go(SceneFlow.DECKS)
	var screen: Node = _app.current_scene()
	screen.set_mode(Story.military().rules_id)
	screen.press_new()
	for kind: UnitKind.Id in [UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SNIPER, UnitKind.Id.COMMANDO, UnitKind.Id.MEDIC]:
		screen.hire(kind)
	screen.select_entry(2)
	screen.hover_kind(UnitKind.Id.COMMANDO)
	return screen.editing_deck().entries.size() == 4 and screen.editing_deck().budget() > DeckRules.versus().budget(Story.military().army)


## 第 2 話までクリアしたあとの話の一覧（持ち物が増え、コストの上限が上がった）。
func _scene_story_list_items() -> bool:
	for i in _main_episode() + 2:
		_app.context.story.clear(Story.military().episodes[i].id)
	return await _scene_story_list()


## 出撃準備で、既定の編成を選んでいるところ（取っておいた部隊は無い）。
func _scene_story_sortie_default() -> bool:
	_app.context.decks.load_data({"decks": []})
	if not await _start_story():
		return false
	if not _at_sortie():
		return false
	return _app.current_scene().chosen_id() == ""


## 守り切る話（(hold_turns を書いた最初の話)）の番号（0 から）。無ければ -1。
func _hold_episode() -> int:
	for i in Story.military().episodes.size():
		if Story.military().episodes[i].hold_turns > 0:
			return i
	return -1


func _scene_story_hold_sortie() -> bool:
	var number := _hold_episode()
	if number == -1 or not await _start_story(number):
		return false
	return _at_sortie()


## 守り切る話の対戦を、CPU どうしで until まで進めて画面に出す。until が無ければ、決着の手前まで進める。
func _hold_battle_until(until := Callable()) -> bool:
	var number := _hold_episode()
	if number == -1 or not await _story_battle(number):
		return false
	var setup: MatchSetup = _scene.source.make_setup(_seed)
	_battle = setup.create_battle()
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "CPU（赤）"] as Array[String])
	var reached := _advance(until if until.is_valid() else func() -> bool: return false)
	if reached != until.is_valid():
		return false
	_scene.start_with(_battle, _scene.source.look(), _seed, setup.scenario.title)
	_scene.stats = _stats
	_scene.battle_log = _log
	return true


func _scene_story_hold_battle() -> bool:
	return await _hold_battle_until(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1)


func _scene_story_hold_last() -> bool:
	return await _hold_battle_until(func() -> bool: return _battle.turn >= _battle.hold_turns and _battle.phase == Unit.Side.PLAYER1)


## 守り切る話で、最後のターンの終わりまで持ちこたえた決着の画面（守り切りで勝つ種だけ）。
## 最後の手は敵（CPU）のターン終了なので、画面に出すと、画面の CPU がそのまま指す。
func _scene_story_hold_result() -> bool:
	if not await _hold_battle_until():
		return false
	if not _battle.is_over():
		var action := _cpu.next_action(_battle)
		if action == null or not await _scene.act(action):
			return false
	while not _battle.is_over():
		await get_tree().process_frame
	var held := _battle.turn == _battle.hold_turns and _battle.capture_turns[Unit.Side.PLAYER1] < Battle.CAPTURE_TURNS_TO_WIN
	for unit in _battle.units:
		if unit.side == Unit.Side.PLAYER2 and unit.kind == UnitKind.Id.KING:
			held = held and _battle.winner == Unit.Side.PLAYER1
			_scene.result_screen().skip()
			return held
	return false


## 全滅させる話（wins に全滅を書いた最初の話）の番号（0 から）。無ければ -1。
func _rout_episode() -> int:
	for i in Story.military().episodes.size():
		if Story.military().episodes[i].wins.has(GameWonEvent.Reason.ROUTED):
			return i
	return -1


## 勝ち方が中ボスの撃破の話（「結晶の番人」）の番号（0 から）。無ければ -1。
func _boss_episode() -> int:
	for i in Story.military().episodes.size():
		if Story.military().episodes[i].wins.has(GameWonEvent.Reason.BOSS_SLAIN):
			return i
	return -1


func _scene_story_boss_sortie() -> bool:
	var number := _boss_episode()
	if number == -1 or not await _start_story(number):
		return false
	return _at_sortie()


func _scene_story_boss_start() -> bool:
	var number := _boss_episode()
	return number != -1 and await _story_battle(number)


func _scene_story_rout_sortie() -> bool:
	var number := _rout_episode()
	if number == -1 or not await _start_story(number):
		return false
	return _at_sortie()


func _scene_story_rout_start() -> bool:
	var number := _rout_episode()
	return number != -1 and await _story_battle(number)


func _scene_story_rout_wide() -> bool:
	if not await _scene_story_rout_start():
		return false
	var size: Vector2i = _scene.battle.board.size
	_look_at(Vector3(size.x / 2.0, 0.0, size.y / 2.0))
	_aim(OrbitCamera.max_distance_for(size), 0.0, OrbitCamera.MIN_PITCH)
	return true


## 魔物の群れの話（敵の軍が無い最初の話）の番号（0 から）。無ければ -1。
## with_king なら、将のいる群れの最初の話。
func _monster_episode(with_king := false) -> int:
	for i in Story.military().episodes.size():
		var episode: RefCounted = Story.military().episodes[i]
		if episode.enemy_army == UnitKind.Army.NONE and (episode.enemy_king or not with_king):
			return i
	return -1


## 話の対戦を、CPU どうしで、敵（プレイヤー2）が skill を使ったあとの人の番の始めまで進めて画面に出す。fantasy なら FANTASY の物語の話。
## 使った駒の id を返す（使わないまま決着しそうなら -1）。
func _battle_until_enemy_skill(episode_id: StringName, skill: Skill.Id, fantasy := false) -> int:
	if fantasy:
		var at: int = _fantasy().episodes.map(func(episode: RefCounted) -> StringName: return episode.id).find(episode_id)
		if at < 0 or not await _start_fantasy(at) or not await _sortie_to_battle():
			return -1
		_scene = _app.current_scene()
	elif not await _story_battle(_military_index(episode_id)):
		return -1
	var setup: MatchSetup = _scene.source.make_setup(_seed)
	_battle = setup.create_battle()
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "CPU（赤）"] as Array[String])
	var used := [-1]
	var watch := func(events: Array[BattleEvent]) -> void:
		for event in events:
			var skill_used := event as SkillUsedEvent
			if skill_used != null and skill_used.skill == skill and used[0] == -1:
				used[0] = skill_used.unit_id
	# 使ったあと、人の番の始めで止める（敵の番の途中で画面に出すと、画面の CPU が続きを指し、カメラがそちらへ寄る）。
	if not _advance(func() -> bool: return used[0] != -1 and _battle.phase == Unit.Side.PLAYER1, watch):
		return -1
	if _battle.unit_by_id(used[0]) == null:
		return -1
	_scene.start_with(_battle, _scene.source.look(), _seed, setup.scenario.title)
	_scene.stats = _stats
	_scene.battle_log = _log
	return used[0]


func _scene_story_horde_raise() -> bool:
	var caller_id := await _battle_until_enemy_skill(&"barrow_rout", Skill.Id.BONE_RAISE)
	if caller_id == -1:
		return false
	var caller := _battle.unit_by_id(caller_id)
	_look_at(BoardView.cell_center(caller.cell))
	_aim(9.0, 0.0, 50.0)
	return true


func _scene_story_drums_talk() -> bool:
	var at: int = _fantasy().episodes.map(func(episode: RefCounted) -> StringName: return episode.id).find(&"crag_drums")
	if at < 0 or not await _start_fantasy(at) or not await _talk_from_sortie():
		return false
	var talk: Node = _app.current_scene()
	while talk.line_index() < talk.line_count() and talk.speaker() != "骨の鼓手":
		talk.press_next()
	return talk.speaker() == "骨の鼓手"


func _scene_story_drums_battle() -> bool:
	var drummer_id := await _battle_until_enemy_skill(&"crag_drums", Skill.Id.WAR_DRUM, true)
	if drummer_id == -1:
		return false
	var drummer := _battle.unit_by_id(drummer_id)
	var charged: Unit = null
	for unit in _battle.units:
		if unit.side == Unit.Side.PLAYER2 and Statuses.has(unit, Status.Type.ASSAULT):
			charged = unit
	if charged == null:
		return false
	_look_at(BoardView.cell_center(drummer.cell))
	_aim(10.0, 0.0, 50.0)
	_scene.hover(charged.cell)
	return true


func _scene_story_monster_talk() -> bool:
	var number := _monster_episode()
	if number == -1 or not await _start_story(number) or not await _talk_from_sortie():
		return false
	for i in 2:
		_app.current_scene().press_next()  # 3 行目（敵の話し手の札）
	return true


func _scene_story_monster_sortie() -> bool:
	var number := _monster_episode()
	if number == -1 or not await _start_story(number):
		return false
	return _at_sortie()


func _scene_story_monster_detail() -> bool:
	if not await _scene_story_monster_sortie():
		return false
	var detail: Control = _app.current_scene().press_face(Unit.Side.PLAYER2, 2)
	return detail != null and detail.visible


func _scene_story_sortie_hover() -> bool:
	if not await _scene_story_sortie():
		return false
	var deploy: Control = _app.current_scene().deploy_map()
	var longest := Vector2i(-1, -1)
	var length := 0
	for cell: Vector2i in deploy.unit_cells():
		deploy.hover_cell(cell)
		var name: String = _app.current_scene().deploy_note().shown_name()
		if name.length() > length:
			length = name.length()
			longest = cell
	deploy.hover_cell(longest)
	return length > 0


func _scene_story_sortie_placed() -> bool:
	if not await _scene_story_sortie():
		return false
	return _move_and_pick(_app.current_scene().deploy_map())


func _scene_story_sortie_detail() -> bool:
	if not await _scene_story_sortie():
		return false
	# 持ち物を持っている駒を探して開く（無ければ、最初の雇った駒）。
	var detail: Control = null
	for index in range(1, 12):
		var opened: Control = _app.current_scene().press_face(Unit.Side.PLAYER1, index)
		if opened == null:
			break
		detail = opened
		if not detail.shown_sheet().items.is_empty():
			break
	if detail != null and detail.shown_sheet().items.is_empty():
		detail = _app.current_scene().press_face(Unit.Side.PLAYER1, 1)
	return detail != null and detail.visible


func _scene_story_monster_start() -> bool:
	var number := _monster_episode()
	if number == -1 or not await _story_battle(number):
		return false
	var brute := _first_unit_of(UnitKind.Id.SKELETON_BRUTE)
	if brute == null:
		return false
	_look_at(BoardView.cell_center(brute.cell))
	_aim(9.0, 0.0, 50.0)
	return true


func _scene_story_monster_info() -> bool:
	if not await _scene_story_monster_start():
		return false
	var brute := _first_unit_of(UnitKind.Id.SKELETON_BRUTE)
	_scene.hover(brute.cell)
	return true


## 場面 story_monster_king の構図: カメラの距離、向き（度）、見る点を将からずらす量（向きが 0 度のときのもの）。
const KING_FRAME_DISTANCE := 8.0
const KING_FRAME_YAW := 70.0
const KING_FRAME_SHIFT := Vector3(0.0, 0.0, -0.8)


func _scene_story_monster_king() -> bool:
	var number := _monster_episode(true)
	if number == -1 or not await _story_battle(number):
		return false
	var king: Unit = null
	for unit: Unit in _scene.battle.units:
		if unit.kind == UnitKind.Id.KING and unit.side == Unit.Side.PLAYER2:
			king = unit
	if king == null:
		return false
	# 骸骨の将は背が高い（quaternius_skeleton.gd の KING_LOOKS の scale）。頭が上の帯と途中の台詞の帯に隠れないよう、
	# 少し引いて、見る点を将の向こう側（カメラから遠い側）へずらし、将を画面の真ん中より下に置く。
	_look_at(BoardView.cell_center(king.cell) + KING_FRAME_SHIFT.rotated(Vector3.UP, deg_to_rad(KING_FRAME_YAW)))
	_aim(KING_FRAME_DISTANCE, KING_FRAME_YAW, 38.0)
	_scene.hover(king.cell)
	var episode: RefCounted = Story.military().episodes[number]
	_scene.clear_talk_for_check()
	_scene.say_for_check([BattleCues.Line.new(1, episode.speakers[1], "骨よ、生きた者を通すな。", episode.figures[1])] as Array[BattleCues.Line])
	return episode.king_looks[1] != &""


## 盤の上の、その種類の最初の駒。いなければ null。
func _first_unit_of(kind: UnitKind.Id) -> Unit:
	for unit: Unit in _scene.battle.units:
		if unit.kind == kind:
			return unit
	return null


## 対戦の途中の会話の札（ターン 1 の台詞を持つ最初の話の、対戦の始め）。
func _scene_story_battle_talk() -> bool:
	for i in Story.military().episodes.size():
		if Story.military().episodes[i].cues.any(func(cue: Array) -> bool: return cue[0] == BattleCues.TURN and cue[1] == 1):
			if not await _story_battle(i):
				return false
			return _scene.talk_line() != null
	return false


func _scene_story_battle_talk_hold() -> bool:
	if not await _scene_story_battle_talk():
		return false
	var line: BattleCues.Line = _scene.talk_line()
	_scene.clear_talk_for_check()
	_scene.set_talk_hold(true)
	_scene.say_for_check([line] as Array[BattleCues.Line])
	for i in 120:
		if _scene.talk_line() != null and not _scene.is_banner_shown():
			break
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	return _scene.is_talk_holding()


## 部隊編成の「ストーリー用」の一覧と、組む画面（いま雇える駒だけ）。
func _scene_decks_story() -> bool:
	await _app.go(SceneFlow.DECKS)
	var screen: Node = _app.current_scene()
	screen.set_mode(Story.military().rules_id)
	screen.press_new()
	for kind: UnitKind.Id in [UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SNIPER, UnitKind.Id.MEDIC]:
		screen.hire(kind)
	screen.select_entry(0)  # 持ち物の欄（まだ持たせられない持ち物は、灰色の「未解放」）
	return screen.is_editing() and screen.editing_deck().rules.id == Story.military().rules_id


func _scene_story_start() -> bool:
	return await _story_battle()


func _scene_story_wide() -> bool:
	if not await _story_battle():
		return false
	var size: Vector2i = _scene.battle.board.size
	_look_at(Vector3(size.x / 2.0, 0.0, size.y / 2.0))
	_aim(OrbitCamera.max_distance_for(size), 0.0, OrbitCamera.MIN_PITCH)
	return true


## 出撃準備の「部隊編成」で、編成（ストーリー用）へ寄り道したところ。
func _scene_story_decks_detour() -> bool:
	if not await _scene_story_sortie():
		return false
	_app.current_scene().press_edit_decks()
	await _app.scene_changed
	return _app.current_id() == SceneFlow.DECKS and _app.current_scene().is_detour()


## 話の対戦を、CPU どうしで決着の手前まで進め、最後の手を画面で指して負ける（敵 = プレイヤー2 が勝つ種だけ）。
func _scene_story_defeat() -> bool:
	if not await _story_battle():
		return false
	# 既定の編成では人の側（CPU が持つ）がほぼ勝つので、負ける局を作るため、人の部隊をスナイパー 1 体にする。
	var weak := Deck.new(Story.military().army, _app.context.story.deck_rules())
	weak.add(UnitKind.Id.SNIPER)
	_scene.source.human_deck = weak
	var setup: MatchSetup = _scene.source.make_setup(_seed)
	_battle = setup.create_battle()
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "CPU（赤）"] as Array[String])
	if _advance(func() -> bool: return false):
		return false
	var action := _cpu.next_action(_battle)
	if _battle.phase != Unit.Side.PLAYER2:
		return false  # 人の側の手で決着する種
	_scene.start_with(_battle, _scene.source.look(), _seed, setup.scenario.title)
	_scene.stats = _stats
	await _scene.act(action)
	if not _battle.is_over() or _battle.winner != Unit.Side.PLAYER2:
		return false
	_scene.result_screen().skip()
	return true


## 話の対戦を、CPU どうしで決着の手前まで進め、最後の手を画面で指して勝つ（人の側 = プレイヤー1 が勝つ種だけ）。
func _story_win() -> bool:
	if not await _story_battle():
		return false
	var setup: MatchSetup = _scene.source.make_setup(_seed)
	_battle = setup.create_battle()
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "CPU（赤）"] as Array[String])
	if _advance(func() -> bool: return false):
		return false
	var action := _cpu.next_action(_battle)
	if _battle.phase != Unit.Side.PLAYER1:
		return false  # 敵の手で決着する（人の側が負ける）種
	_scene.start_with(_battle, _scene.source.look(), _seed, setup.scenario.title)
	_scene.stats = _stats
	await _scene.act(action)
	if not _battle.is_over() or _battle.winner != Unit.Side.PLAYER1:
		return false
	_scene.result_screen().skip()
	return true


func _scene_story_result() -> bool:
	return await _story_win()


func _scene_story_after() -> bool:
	if not await _story_win():
		return false
	var screen: Control = _scene.result_screen()
	while screen.enabled_buttons().is_empty():
		await get_tree().process_frame
	screen.press_continue()
	await _app.scene_changed
	return _app.current_id() == SceneFlow.TALK


func _scene_story_next_choice() -> bool:
	if not await _scene_story_after():
		return false
	var talk: Node = _app.current_scene()
	for i: int in talk.line_count() + 1:
		if talk.is_choosing():
			break
		talk.press_skip()
		talk.press_next()
	return talk.is_choosing()


func _scene_story_battle_menu() -> bool:
	if not await _story_battle():
		return false
	_app.open_menu()
	return _app.system_menu().is_open() and _app.system_menu().item_ids().has(&"exit:episodes")


func _scene_story_unlock() -> bool:
	if not await _scene_story_after():
		return false
	var talk: Node = _app.current_scene()
	talk.press_skip()
	return talk.speaker() == Story.notice_name()


## 終わりの 1 つ前の話（ストーリー専用の持ち物が手に入る）の、あとの会話の知らせの行。対戦はせず、会話の場面だけを流れで始める。
func _scene_story_item_unlock() -> bool:
	var campaign: RefCounted = Story.military()
	var episode: RefCounted = campaign.episodes[campaign.episodes.size() - 2]
	var talk := Story.talk_of(episode, [])
	for news: Dictionary in Story.unlocked_before(episode).news_of(episode):
		var line := {"side": Story.NOTICE_SIDE, "name": Story.notice_name()}
		line.merge(news)
		talk["lines"].append(line)
	var run := Run.new()
	run.exit = SceneFlow.TITLE
	run.add(Story.TALK, talk)
	_app.context.start_run(run)
	await _app.scene_changed
	var screen: Node = _app.current_scene()
	return _app.current_id() == SceneFlow.TALK and screen.speaker() == Story.notice_name()


## FANTASY の物語を全部クリアしたあとの部隊編成。パラディン（前衛）を選び、持ち物を持たせたところ。
func _scene_story_items_decks() -> bool:
	return await _items_decks(_fantasy(), [UnitKind.Id.PALADIN, UnitKind.Id.SORCERER, UnitKind.Id.SPELLBLADE, UnitKind.Id.PRIEST], 0,
			[Equipment.Id.DRAGON_SCALE, Equipment.Id.TRAIL_MAP])


## MILITARY の物語を全部クリアしたあとの部隊編成。コマンドー（奇襲）を選び、ジェットパックを持たせたところ。
func _scene_story_items_military() -> bool:
	return await _items_decks(Story.military(), [UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SNIPER, UnitKind.Id.COMMANDO, UnitKind.Id.MEDIC], 2,
			[Equipment.Id.JET_PACK])


## 物語 campaign を全部クリアして、部隊編成のストーリー用で kinds を雇い、selected 番目の駒に items を持たせる。
func _items_decks(campaign: RefCounted, kinds: Array[UnitKind.Id], selected: int, items: Array[Equipment.Id]) -> bool:
	_app.context.story.choose_campaign(campaign)
	for episode: RefCounted in campaign.episodes:
		_app.context.story.clear(episode.id)
	await _app.go(SceneFlow.DECKS)
	var screen: Node = _app.current_scene()
	screen.set_mode(campaign.rules_id)
	screen.press_new()
	for kind in kinds:
		screen.hire(kind)
	screen.select_entry(selected)
	for item in items:
		screen.equip(item)
	return screen.editing_deck().entries[selected].equipment == items


func _scene_story_cleared() -> bool:
	# 「クリア済み」の印は、遊べる物語の全部の話をクリアしたとき。クリアは、いま選んでいる物語の記録に書く。
	for campaign: RefCounted in Story.campaigns():
		_app.context.story.choose_campaign(campaign)
		for episode: RefCounted in campaign.episodes:
			_app.context.story.clear(episode.id)
	await _app.go(SceneFlow.TITLE)
	return _app.current_scene().story_label().contains("クリア済み")


## 景色の場面の名前を、[マップ, 見た目, 構図] に分ける（見た目を書かなければ、マップの見た目）。読めなければ空。
func _scape_parts(name: String) -> Array:
	var parts := name.trim_prefix(SCAPE).split(".")
	if parts.size() == 2:
		parts.insert(1, "")
	if parts.size() != 3:
		return []
	var look := StringName(parts[1])
	if VersusFields.has(StringName(parts[0])) and VersusFields.is_generated(StringName(parts[0])):
		look = look if look != &"" else VersusFields.look_of(StringName(parts[0]))
	elif not Maps.find(parts[0]).is_empty():
		look = look if look != &"" else StringName(Maps.find(parts[0])["look"])
	else:
		return []
	return [parts[0], look, parts[2]]


func _scape_known(name: String) -> bool:
	var parts := _scape_parts(name)
	return not parts.is_empty() and StageLook.THEMES.has(parts[1]) and SCAPE_VIEWS.has(parts[2])


## マップの景色を、決まった構図で撮る（どのマップも同じ構図。並べて見比べるため）。部隊は対戦モードのいつもの編成。
func _scape(name: String) -> bool:
	var parts := _scape_parts(name)
	var defined: Scenario
	if VersusFields.has(StringName(parts[0])) and VersusFields.is_generated(StringName(parts[0])):
		defined = VersusFields.scenario_of(StringName(parts[0]))
	else:
		var found: Dictionary = Maps.find(parts[0])
		defined = Scenario.on_map(found["map"], found["title"])
	var armies: Array[UnitKind.Army] = [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]
	var setup := MatchSetup.humans_on(defined, _seed, MatchSetup.default_deck(armies[0]), MatchSetup.default_deck(armies[1]))
	if parts[2] == "paint":
		setup.trials.append(TrialRules.BATTERY)  # 砲台のマスも並べる
	_battle = setup.create_battle()
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "プレイヤー2（赤）"] as Array[String])
	_scene.start_with(_battle, parts[1], _seed, defined.title)
	var size: Vector2i = _battle.board.size
	var middle := Vector3(size.x / 2.0, 0.0, size.y / 2.0)
	match parts[2]:
		"wide":  # いちばん引いて、低い角度で。盤の全体と、その向こうの景色と空
			_look_at(middle)
			_aim(OrbitCamera.max_distance_for(size), 0.0, OrbitCamera.MIN_PITCH)
		"side":  # 横から、いちばん引いて低い角度で。別の向きの景色と空
			_look_at(middle)
			_aim(OrbitCamera.max_distance_for(size), 115.0, OrbitCamera.MIN_PITCH)
		"close":  # 盤の真ん中に寄って。障害物・森・平地の見分け
			_look_at(middle)
			_aim(13.0, 25.0, 45.0)
		"out":  # 盤の左の外を、近くから。盤のすぐ外に置いたものの形と大きさ
			_look_at(Vector3(-7.0, 0.0, size.y / 2.0))
			_aim(15.0, -50.0, 38.0)
		"range":
			return _scape_range(parts[1], defined.title)
		"paint":
			return _scape_paint()
	return true


## 景色の場面の「paint」: 盤の真ん中の平地に、範囲の色を帯にして並べ（上から移動・攻撃の相手・回復・スキル・ポータルの対・道）、
## 右に敵の全員の脅威範囲の斜線を重ねる。砲台（試しの決まり）とポータルのあるマップなら、その上にも移動の色を塗る。
## どの景色でも同じ並びなので、景色ごとに並べて、どの色が地面に沈むかを見比べる。
func _scape_paint() -> bool:
	var board := _battle.board
	var size: Vector2i = board.size
	var origin := Vector2i(size.x / 2 - 3, size.y / 2 - 3)
	var bands: Array[StringName] = [&"move", &"target", &"heal", &"skill", &"portal", &"path"]
	var samples := {}
	for kind in bands:
		samples[kind] = [] as Array[Vector2i]
	samples[&"threat"] = [] as Array[Vector2i]
	for row in bands.size():
		for column in 6:
			var cell := origin + Vector2i(column, row)
			if not board.in_bounds(cell):
				continue
			samples[bands[row]].append(cell)
			if column >= 4:
				samples[&"threat"].append(cell)
	for cell: Vector2i in board.battery_cells + board.portal_exits.keys():
		samples[&"move"].append(cell)
	_scene.show_paint_samples(samples)
	_look_at(BoardView.cell_center(origin + Vector2i(3, 3)))
	_aim(14.0, 20.0, 50.0)
	return true


## 景色の場面の「range」: 両軍が近づいたターン 3 の先手の番で、駒を 1 つ選び（移動範囲）、敵の全員の脅威範囲も出す。
## 範囲の色と駒が、その景色の地面に沈まないかを見る。
func _scape_range(look: StringName, title: String) -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_scene.start_with(_battle, look, _seed, title)
	var unit := _own_units()[0]
	for own in _own_units():
		if own.kind != UnitKind.Id.KING and _battle.can_act(own):
			unit = own
			break
	_scene.click_cell(unit.cell)
	_scene.toggle_threat()
	_scene.focus_camera(unit.cell)
	return _scene.is_threat_shown()


func _new_battle(trials: Array[StringName] = []) -> void:
	var choice: RefCounted = MatchChoice.new()
	choice.field = _field
	choice.cpu_opponent = false
	for trial in trials:
		choice.set_trial(trial, true)
	_scene.source = choice
	_battle = choice.to_setup(_seed).create_battle()
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "CPU（赤）"] as Array[String])


## いまの _battle を画面に出す（駒の見た目は、いまの状態から作る）。
## 対戦の画面の中央の知らせ（番の知らせなど）が消えるまで待つ。描画の遅い環境では SETTLE のうちに消えないことがある。
## 知らせを撮る場面のために、待つのは BANNER_WAIT 秒まで。
func _banner_gone() -> void:
	if _app.current_id() != SceneFlow.BATTLE or _scene.setup_panel().visible or _app.system_menu().is_open() or _scene.log_panel().is_open() or _scene.unit_detail().visible:
		return  # 時間が止まっている（知らせは消えない）
	var waited := 0.0
	while _scene.is_banner_shown() and waited < BANNER_WAIT:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _show() -> void:
	_scene.start_with(_battle, VersusFields.look_of(_field), _seed, VersusFields.title_of(_field))


## カメラの見ている地点を point にする（寄る動きは待たない）。
func _look_at(point: Vector3) -> void:
	_scene.place_camera(point)


## カメラの距離、向き（度）、見下ろす角度（度）を決める。
func _aim(distance: float, yaw_degrees: float, pitch: float) -> void:
	_scene.set_camera_view(distance, yaw_degrees)
	_scene.set_camera_pitch(pitch)


## CPU どうしで行動を 1 つずつ進め、行動と行動の間で until が真になったら止めて真を返す。
## 止めるのは、選んでいる駒も進化の途中も無いときだけ。決着する行動は進めずに偽を返す（_battle は決着の手前で止まる）。
## watch には、行動ごとに起きたことを渡す。
func _advance(until: Callable, watch := Callable()) -> bool:
	for i in MAX_ACTIONS:
		if _battle.acting_unit_id == 0 and _battle.evolving_unit() == null and until.call():
			return true
		var action := _cpu.next_action(_battle)
		if action == null:
			return false
		var trial := _battle.clone()
		trial.apply(action)
		if trial.is_over():
			return false
		var result := _battle.apply(action)
		_stats.feed_all(result.events)
		_log.feed_all(result.events)
		if watch.is_valid():
			watch.call(result.events)
	return false


## マウスの下のマスが塗られたり、マスの説明が出たりしないよう、マウスを下の帯の左（操作の説明の上）に置く。
func _park_mouse() -> void:
	var at := Vector2(100, get_viewport().get_visible_rect().size.y - 10)
	get_viewport().warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)


func _own_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in _battle.units:
		if unit.side == _battle.phase:
			result.append(unit)
	return result


static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _arg(args: PackedStringArray, key: String) -> String:
	var at := args.find(key)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else ""


func _quit(message: String, code: int) -> void:
	if code == 0:
		print(message)
	else:
		printerr(message)
	get_tree().quit(code)
