extends "res://tools/shots/story_patrol_scenes.gd"
## ゲームの決まった場面を画像に撮る（PR に貼るため）。`-- --shots <場面,…|all> --out <ディレクトリ>` を付けて起動すると、
## アプリ（app.gd）が、タイトル → 対戦設定 → 対戦 と人と同じ道で対戦に入ったところで、このノードを足す。
## 撮り終えたら終わる。使い方は docs/screenshots.md。
## 対戦の場面は対戦の画面（battle_screen.gd）で撮り、タイトルと対戦設定の場面は、アプリをその場面へ切り替えて撮る。
##
## 場面はどれも、種を決めた対戦（MatchSetup）を CPU どうしで進めて作る。人の操作と同じ入口で駒を選ぶので、
## 毎回同じ絵になる。場面の条件が来なければ、種を替えて作り直す（MORE_SEEDS まで）。それでも作れない場面は飛ばして、
## 最後にまとめて失敗を報告する。場面を足すときは、SCENES に名前と説明を足し、同じ名前の _scene_<名前>() を書く
## （その場面まで状態を作るだけ。撮るのはこのノードがやる）。_scene_<名前>() は、画面ごとのファイル（tools/shots/*_scenes.gd）に置く。
## ここは、場面の一覧と、撮る流れ（場面ごとに状態を戻し、作り、撮る）だけ。場面を作る道具は tools/shots/shot_base.gd。


## 場面の名前 -> 説明（撮る順）。
const SCENES := {
	"title": "タイトルの場面（起動した直後）",
	"title_scape_ruins": "タイトルの場面の背景を、石の遺跡の景色にしたところ（景色は起動のたびと時間ごとに替わる）",
	"title_scape_night": "タイトルの場面の背景を、月夜の結晶の岩山の景色にしたところ",
	"title_scape_barrow": "タイトルの場面の背景を、古戦場の景色にしたところ",
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
	"deck_trait": "部隊編成: 騎士領の部隊で軍略の「誓い」を選び、2 人を結んだところ（単騎の札に乗せて、文を読んでいる）",
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
	"deck_healer_detail": "部隊編成: 衛生兵の札の「詳細」で、ステータスの窓を開いたところ（名前の右に回復役の攻撃。後ろの雇える駒の札にも「攻撃」）",
	"healer_menu": "回復役を敵の届くマスへ動かして、メニューに「攻撃」と「回復」が出ている（攻撃の相手は赤、回復の相手は緑）",
	"healer_attack": "回復役のメニューの「攻撃」を押して、敵にマウスを乗せている（攻撃 4 の予測）",
	"info_healer": "対戦の途中で、自分の回復役にマウスを乗せた駒の情報（名前の右に「攻撃 4」）",
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
	"barricade_worn": "置いたばかりの盾と、削られた盾（上に残りの耐久の棒。削られた盾を押して、情報の枠に出している）",
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
	"battery_cell": "砲台（マップの物）のマスをクリックして、説明が出ている（砲台のある、並びの先頭のマップ）",
	"battery": "砲台に乗った後衛を選んだところ（射程が伸びている。砲台のある、並びの先頭のマップ）",
	"stronghold_cell": "拠点のマスをクリックして、説明が出ている（中央平原）",
	"stronghold_hover": "拠点のマスにマウスを乗せて、下の帯にマスの説明が出ている（長い説明が 2 行に折り返され、切れない）",
	"stronghold_three": "拠点が 3 つあるときの拠点の札の見本（いまの決まりでは拠点は盤に 1 つ。札の形だけを手で作った: 青・だれのものでもない・赤の旗と、陣営ごとの確保の数）",
	"stronghold": "拠点に駒が乗り、どちらかがあと 1 回の確保で勝つところ（勝利条件の札と確保の数。迷宮回廊）",
	"setup_stronghold": "対戦設定で、選べる決まりの「拠点」を「あり」にしたところ",
	"setup_seam": "対戦設定の「縫い目の様子」の行（既定は「ランダム」）",
	"rules_notice": "対戦モードの対戦の始めの「対戦ルール」（勝利条件 3 つの札。縫い目の様子の無い対戦）",
	"sign_note": "対戦中に、上の帯の下の縫い目の様子の名前をクリックしたところ（札 1 枚の窓）",
	"signs_start": "縫い目の様子が 2 つ付いた対戦の始め（始めの知らせに様子の名前。上の帯の下の左に、2 つの印と名前）",
	"trait_note": "対戦中に、上の帯の軍略の札（集中砲火）をクリックしたところ（軍略 1 つの窓）",
	"trait_start": "軍略の線（補給線の連邦と、誓いの騎士領）が出ている対戦の始め",
	"trait_focus": "集中砲火: 味方が当てた敵の頭の上の札（+2）と足元の輪、2 人目の攻撃の予測（集中砲火 +2）",
	"trait_vengeance": "仇討ち: 味方を倒した敵の頭の上の札（+4）と足元の輪、その敵への攻撃の予測（仇討ち +4）",
	"trait_marks": "軍略の札が、ほかの表示と重なる所（拠点の上の敵、バリアの中の敵に集中砲火の札。仇討ちの札の付いた自分の兵を選んでいる）",
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
	"story_fantasy_forest_sortie": "ストーリー: FANTASY の物語の「森の守り」（リュエルの森）の出撃準備（既定の編成、勝利条件の札、敵の部隊）",
	"story_fantasy_forest_wide": "ストーリー: リュエルの森（FANTASY の物語のための、森の多いマップ）を、いちばん引いて見ている",
	"story_fantasy_decks": "ストーリー: 部隊編成の「ストーリー用」を FANTASY の物語に切り替えて組むところ（FANTASY の駒だけ、最初のコスト上限）",
	"story_open_all": "ストーリー: 確かめ用の解放（F5）で全部の話を開いた話の一覧（左下の隅に印。どの話も選べる）",
	"story_list": "ストーリー: 物語を選んだあとの話の一覧（最初の話だけ選べる）",
	"story_list_cleared": "ストーリー: 本編の 1 話目をクリアしたあとの話の一覧（次の話が選べる。いま雇える駒が増えた）",
	"story_tutorial_list": "ストーリー: 何もクリアしていない話の一覧（頭のチュートリアルの話。番号に「（演習）」）",
	"story_tutorial_sortie": "ストーリー: チュートリアルの話（演習「撃ち合い」）の出撃準備（この話で覚えること、決まっている部隊）",
	"story_sortie": "ストーリー: 出撃準備（マップと初期位置、勝利条件の札、敵の部隊、出撃する部隊を選ぶ）",
	"story_sortie_squads": "ストーリー: 出撃準備で、取っておいた部隊が 5 つあるところ（選べる部隊の並びに 3 部隊ぶんが見え、続きは欄の中で送る）",
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
	"story_hold_sortie": "ストーリー: 守り切る話（第 3 話）の出撃準備（勝利条件の札が守り切る・将の撃破・本陣の占拠の 3 枚）",
	"story_hold_battle": "ストーリー: 守り切る話の対戦の途中（上の帯の勝利条件の札に「あと N ターン守り切れば勝ち」）",
	"story_hold_last": "ストーリー: 守り切る話の最後のターン（勝利条件の札が「最後のターン: 守り切れば勝ち」で、赤く目立つ）",
	"story_hold_result": "ストーリー: 守り切る話で、最後のターンの終わりまで持ちこたえて勝った決着の画面（「最後まで守り切った」）",
	"story_rout_sortie": "ストーリー: 全滅させる話（第 4 話）の出撃準備（2 つ目の手で作ったマップ「結晶の岩山」。勝利条件の札は「全滅」の 1 枚）",
	"story_rout_start": "ストーリー: 全滅させる話の対戦の始め（結晶の岩山を、双子結晶の見た目で。上の帯の勝利条件の札「勝利条件: 敵の全滅のみ」）",
	"story_boss_sortie": "ストーリー: 中ボスを倒す演習（「結晶の番人」）の出撃準備（勝利条件の札は中ボスの撃破の 1 枚）",
	"story_boss_start": "ストーリー: 中ボスを倒す演習の対戦の始め（上の帯の勝利条件の札「勝利条件: 結晶の番人の撃破のみ」）",
	"story_rout_wide": "ストーリー: 結晶の岩山を、いちばん引いて見ている（岩山と、両端の回り道、真ん中のポータル）",
	"story_monster_talk": "ストーリー: 魔物の群れの話の、対戦の前の会話（将のいない群れ。敵の話し手「亡者の術師」の札と、骸骨術師の姿）",
	"story_horde_raise": "ストーリー: 将のいない群れの話「古戦場の亡者」で、骸骨術師が骨起こしで骸骨兵を起こしたあとの人の番（術師に寄って見る。旗の下は空）",
	"story_drums_talk": "ストーリー: FANTASY の物語「亡者の太鼓」の前の会話（敵の話し手「亡者の鼓手」の札と、骸骨鼓手の姿）",
	"story_drums_battle": "ストーリー: 「亡者の太鼓」で、骸骨鼓手が骨太鼓を鳴らしたあとの人の番（周りの亡者に突撃。突撃の付いた骸骨兵にマウスを乗せた駒の情報。上の帯の札は「勝ち: 敵の全滅」）",
	"story_monster_sortie": "ストーリー: 魔物の群れの話（軍に属さない敵）の出撃準備（敵の部隊は「軍なし」の骸骨）",
	"story_sortie_detail": "ストーリー: 出撃準備で、味方の駒のアイコン（持ち物つき）を押して詳しい説明を開いたところ",
	"story_sortie_hover": "ストーリー: 出撃準備の初期位置で、名前のいちばん長い駒にマウスを乗せたところ（駒の欄の中身が替わっても、板もまわりも動かない。story_sortie と並べる）",
	"story_sortie_placed": "ストーリー: 出撃準備の初期位置で、駒を 1 体動かし、もう 1 体を選んでいるところ（「おまかせ」が押せる）",
	"story_monster_detail": "ストーリー: 魔物の群れの話の出撃準備で、敵の骸骨のアイコンを押して詳しい説明を開いたところ",
	"story_monster_start": "ストーリー: 魔物の群れの話の対戦の始め（古戦場。骸骨兵・骸骨射手・骸骨重兵の群れに寄って見る）",
	"story_monster_king": "ストーリー: 将のいる魔物の群れの話（墓守）で、敵の将（骸骨の将の姿。ルールの上では将）にマウスを乗せた駒の情報と、敵の将の途中の台詞（骸骨の将のアイコン）",
	"story_monster_info": "ストーリー: 魔物の群れの話で、骸骨重兵にマウスを乗せた駒の情報（所属は「魔物」。スキル・持ち物の欄は無い）",
	"story_patrol_bats": "ストーリー: 番外の話「岩山の蝙蝠」の対戦の始め（大蝙蝠の群れに寄って、大蝙蝠にマウスを乗せた駒の情報。特性の札）",
	"story_patrol_knot": "ストーリー: 番外の話「ほつれた野」で、倒れたほつれが結び目を残したあとの人の番（結び目のマスにマウスを乗せたマスの説明）",
	"story_patrol_needles": "ストーリー: 番外の話「針の峠」の対戦の始め（番人のそばの糸針に寄って、糸針にマウスを乗せた駒の情報）",
	"story_patrol_eaters": "ストーリー: 番外の話「石喰いの採掘場」の対戦の始め（糸喰いに寄って、糸喰いにマウスを乗せた駒の情報。特性の札）",
	"story_patrol_spider": "ストーリー: 番外の話「石喰いの採掘場」の対戦の始め（糸蜘蛛に寄って、糸蜘蛛にマウスを乗せた駒の情報）",
	"story_patrol_snare": "ストーリー: 番外の話「石喰いの採掘場」で、糸蜘蛛に絡められた人の駒がいる人の番（その駒にマウスを乗せた駒の情報。状態の欄に絡み）",
	"story_patrol_crab": "ストーリー: 番外の話「迎えを待つ谷」の対戦の始め（殻蟹に寄って、殻蟹にマウスを乗せた駒の情報。特性の札）",
	"story_patrol_shroom": "ストーリー: 番外の話「迎えを待つ谷」の対戦の始め（糸茸に寄って、糸茸にマウスを乗せた駒の情報。特性の札）",
	"story_patrol_vale": "ストーリー: 番外の話「迎えを待つ谷」の対戦の途中（群れが寄ってきた盤を、上から広く）",
	"story_patrol_spores": "ストーリー: 番外の話「迎えを待つ谷」で、糸茸の隣の人の駒が攻撃の相手を選ぶ（予測の注に「胞子で弱まる」）",
	"story_patrol_rules_eaters": "ストーリー: 番外の 4 話目「石喰いの採掘場」の対戦の始め（対戦ルールの札と上の帯。勝ちは敵の全滅）",
	"story_patrol_rules_vale": "ストーリー: 番外の 5 話目「迎えを待つ谷」の対戦の始め（対戦ルールの札と上の帯。守り切る 8 ターン）",
	"story_patrol_crab_far": "ストーリー: 番外の 5 話目で、離れて攻撃する駒が攻撃の相手を選ぶ。届く距離の殻蟹は離れているので狙えない（殻蟹にマウスを乗せる。範囲の色と駒の情報）",
	"story_patrol_burst": "ストーリー: 番外の 4 話目で、人の駒が糸喰いを倒し、腹の糸が弾けた瞬間（演出の途中。届いたマスの色と「弾けた」）",
	"story_battle_talk_hold": "ストーリー: 遊ぶときの対戦の途中の会話（送られるまで盤を止める。帯の右に送りの印、下の帯に「クリック・Enter: 台詞を送る」）",
	"story_battle_talk": "ストーリー: 対戦の途中の会話（始めに台詞のある最初の話。上の帯のすぐ下の真ん中の、細い帯。対戦は止めない。ログにも残る）",
	"story_cleared": "ストーリー: 全部の話をクリアしたあとのタイトル（「ストーリー」に済みの印）",
}


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
		if _app.current_id() == SceneFlow.BATTLE:
			# カメラが寄り終わってから、メニューと予測のパネルを置き直す（寄る間は前に選んだ側をひいきするので、
			# 置き場所が撮る時刻で変わる。場面 marks・move）。
			await _camera_still()
			_scene.replace_panels()
			await get_tree().process_frame
		if not await _capture(name):
			return
	if not failed.is_empty():
		_quit("screenshots: 作れなかった場面: %s" % ", ".join(failed), 1)
		return
	_quit("screenshots: OK", 0)


## 場面を作る前に、前の場面の状態を戻し、種 seed の新しい対戦を用意する。
func _reset(seed: int) -> void:
	_app.system_menu().close()
	if _app.quit_window.is_open():
		_app.quit_window.close()  # 前の場面（window_close）の × の確かめを閉じる（開いたままだと時間が止まり、次の場面が進まない）
	_app.context.settings.reset_all()
	if OS.get_cmdline_user_args().has("--no-effects"):
		_app.context.settings.set_value(&"screen_effects", false)  # tools/screenshots.sh の --no-effects（画面の効果を切って撮る）
	for number in range(1, 4):
		_app.context.slots.remove(number)  # 前の場面が書いたセーブのスロットを持ち越さない（取っておく先は無いので、覚えているものだけ）
	_app.context.story.load_data({})  # 前の場面（ストーリー）のクリアの記録を持ち越さない
	_app.context.story.open_all = false  # 前の場面（story_open_all）の確かめ用の解放（F5）も持ち越さない（残ると、記録に書かず、隅に印が出る）
	_app.context.story.choose_campaign(Story.military())  # 前の場面が選んだ物語も持ち越さない
	_app.context.match_choice = MatchChoice.new()  # 前の場面が選んだマップと決まりも持ち越さない（マップ選択の背景は、選んでいるマップの景色）
	_app.system_menu().settings_panel().scroll_to_top()  # 前の場面（settings_screen）で下まで送ったオプションの画面を戻す
	if _app.current_id() != SceneFlow.BATTLE or _app.context.run != null:
		_app.context.run = null  # 流れ（ストーリーの話）の中の対戦の場面は使わない
		_app.context.match_choice.cpu_opponent = false
		await _app.go(SceneFlow.BATTLE)
	_scene = _app.current_scene()
	_scene.log_panel().close()
	_scene.unit_detail().close_detail()
	_scene.setup_panel().visible = false
	_scene.hide_sign_note()  # 前の場面（sign_note）の札の窓を閉じる
	_scene.toggle_trait_note(-1)  # 前の場面（trait_note）の軍略の窓も閉じる
	_scene.set_opponent(false)  # 撮る間は CPU に番を進めさせない
	_scene.hover(Vector2i(-1, -1))  # 前の場面で乗せたことにしたマウスを戻す
	_scene.hover_menu_item(&"")  # 前の場面（menu_note）でメニューの項目に乗せたことにしたマウスも戻す（残ると予測のパネルが出ない）
	if _scene.is_threat_shown():
		_scene.toggle_threat()  # 前の場面で出した、敵の全員の脅威範囲を消す
	_park_mouse()  # 本物のマウスも、前の場面で置いた所から戻す（演出の途中を撮る場面は、撮る前に置き直さないので、マウスの下の駒の情報が出てしまう）
	_field = VersusFields.PLAIN
	_seed = seed
	_new_battle()
	_aim(22.0, 0.0, OrbitCamera.DEFAULT_PITCH)  # 前の場面で動かしたカメラを戻す（ほかの場面は、始めの向きと角度で撮る）
	# 戻り終わるまで待つ（寄る途中で場面がログやメニューを開くと、時間が止まり、前の場面のカメラの名残りのまま撮れる）。
	await _camera_still()
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
