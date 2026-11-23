class_name Seam
extends RefCounted
## 縫い目の様子（docs/seam-signs.md）。その対戦のマップに付く、気候のような効果。
##
## 対戦モードでは、選べる決まり OptionalRules.SEAM（既定は入 =「ランダム」）の対戦で、対戦ごとに 0〜DRAWN 個がめくられる（数も札も対戦の種で決まる）。
## ストーリーでは、話のファイルが指定した様子（Scenario.signs）が、いつも付く。
## 様子は、その対戦のあいだずっと効く条件で、どちらのプレイヤーにも同じに効く。対戦中に切る操作は無い。
## - 札の山は Sign の全部。その盤で効かない札（ポータルの無い盤の「仮縫いのずれ」など）は、山から抜く（applies）
## - 2 枚目は、1 枚目と打ち消し合わない札（CLASHES）から引く
## - めくるのは、対戦の乱数（Battle.rng）とは別の乱数（盤も、対戦の進みも変えない）
##
## 札の効果は、ルールの各所が読む（どれも対戦が Battle.signs に札を持つときだけ。持たない対戦では何も変わらない）:
## 駒の能力値（equip。射程・巡航の移動力）、必殺技のゲージ（gauge_gain）、中立の湧き直し（respawn_percent）、
## 森の軽減（forest_rate_percent）、スキルのクールダウン（cooldown_of）、ポータルの対（arm_board）。

## 札。並びは山の順（めくる前に、この順から混ぜる）。名前と効果の文は画面の文の表（game/text/names.csv の sign.<鍵>。鍵は KEYS）。
enum Sign {
	HAZE,  ## 天裂の名残り: 射程 HAZE_FROM 以上の攻撃は、射程 -HAZE_CUT
	BRIM,  ## 糸の満ち: 必殺技のゲージが BRIM_PERCENT % の速さでたまる
	LOOSE,  ## 糸のゆるみ: 結晶泉の中立の駒が LOOSE_RESPAWN_PERCENT % で湧き直す
	HUSH,  ## 骨の眠り: 結晶泉の中立の駒が湧き直さない（ターン 1 の湧きだけ）
	SHIFT,  ## 仮縫いのずれ: ポータルの行き先が入れ替わる
	GALE,  ## 縫い代の風: 巡航の移動力 +GALE_CRUISE
	GLEAM,  ## 天裂の光: 後衛の射程 +GLEAM_RANGE
	THICKET,  ## 深い茂み: 森にいる駒が受ける攻撃のダメージが THICKET_RATE_PERCENT %
	TAUT,  ## 張りつめた糸: スキルのクールダウンが TAUT_CUT ターン短い
}

## 札の鍵（画面の文の表、集計の道具、テストで使う）。Sign の順。
const KEYS: Array[StringName] = [&"haze", &"brim", &"loose", &"hush", &"shift", &"gale", &"gleam", &"thicket", &"taut"]

## 1 回の対戦でめくる札の数の上限。
const DRAWN := 2
## めくる札の数（0, 1, …, DRAWN）の重み。何も付かない日も、1 つの日も、2 つの日もある（気候のように）。
const DRAW_WEIGHTS: Array[int] = [1, 2, 1]

## 打ち消し合うので、同じ対戦に並べない札の組。
const CLASHES: Array[Array] = [[Sign.LOOSE, Sign.HUSH], [Sign.HAZE, Sign.GLEAM]]

## 天裂の名残り: 射程がこの値以上の攻撃（砲台で伸びたものも）が縮む。
const HAZE_FROM := 3
## 天裂の名残り: 縮む射程。
const HAZE_CUT := 1
## 糸の満ち: 必殺技のゲージのたまり方（いつもを 100 として）。
const BRIM_PERCENT := 150
## 糸のゆるみ: 結晶泉に中立の駒が湧き直す確率（いつもは Neutral.RESPAWN_CHANCE_PERCENT）。
const LOOSE_RESPAWN_PERCENT := 70
## 縫い代の風: 巡航の移動力に足す値（巡航のいつもの移動力は、移動力の 2 倍）。
const GALE_CRUISE := 2
## 天裂の光: 後衛の射程に足す値。
const GLEAM_RANGE := 1
## 深い茂み: 森にいる駒が受ける攻撃のダメージ（いつもは Combat.FOREST_DAMAGE_RATE_PERCENT）。
const THICKET_RATE_PERCENT := 60
## 張りつめた糸: スキルのクールダウンから引くターン数（1 より短くはならない）。
const TAUT_CUT := 1


static func key(sign: Sign) -> StringName:
	return KEYS[sign]


## 鍵 name の札。知らない鍵なら -1。
static func from_key(name: StringName) -> int:
	return KEYS.find(name)


## 盤 board で、札 sign が効くか（効かない札は山から抜く）。
static func applies(sign: Sign, board: Board) -> bool:
	match sign:
		Sign.SHIFT:
			return board.portal_exits.size() >= 4  # 対が 2 つ以上
		Sign.LOOSE, Sign.HUSH:
			return not board.font_cells.is_empty()
		Sign.THICKET:
			return _has_forest(board)
	return true


## 札 a と b を同じ対戦に並べられるか。
static func compatible(a: int, b: int) -> bool:
	if a == b:
		return false
	for pair: Array in CLASHES:
		if pair.has(a) and pair.has(b):
			return false
	return true


## 種 battle_seed の対戦でめくる札の数（0〜DRAWN。DRAW_WEIGHTS の重みで、種で決まる）。
static func draw_count(battle_seed: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([&"seam_count", battle_seed])
	var total := 0
	for weight in DRAW_WEIGHTS:
		total += weight
	var roll := rng.randi_range(0, total - 1)
	for count in DRAW_WEIGHTS.size():
		roll -= DRAW_WEIGHTS[count]
		if roll < 0:
			return count
	return 0


## 盤 board の、種 battle_seed の対戦でめくる札（draw_count 枚。めくった順）。同じ盤と種なら、いつも同じ札。
## 対戦の乱数とは別に引く。山の札が足りなければ、めくれただけ。
static func draw(board: Board, battle_seed: int) -> Array[int]:
	var count := draw_count(battle_seed)
	var deck: Array[int] = []
	for sign: int in Sign.values():
		if applies(sign as Sign, board):
			deck.append(sign)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([&"seam", battle_seed])
	for i in range(deck.size() - 1, 0, -1):  # 混ぜる（並びの順から、種で決まる順に）
		var j := rng.randi_range(0, i)
		var held := deck[i]
		deck[i] = deck[j]
		deck[j] = held
	var drawn: Array[int] = []
	for sign in deck:
		if drawn.size() >= count:
			break
		if drawn.all(func(other: int) -> bool: return compatible(other, sign)):
			drawn.append(sign)
	return drawn


## 話のファイルの様子の並び names（鍵の並び）を札にする。知らない鍵、重なる札、打ち消し合う札があれば、その鍵を problems に足す。
static func from_keys(names: PackedStringArray, problems: Array[String] = []) -> Array[int]:
	var signs: Array[int] = []
	for name in names:
		var sign := from_key(StringName(name.strip_edges()))
		if sign < 0 or not signs.all(func(other: int) -> bool: return compatible(other, sign)):
			problems.append(name.strip_edges())
			continue
		signs.append(sign)
	return signs


## 対戦 battle に札 signs を入れる（MatchSetup.create_battle が、駒を置く前に呼ぶ）。盤に効く札は、ここで盤を変える（arm_board）。
static func arm(battle: Battle, signs: Array[int]) -> void:
	battle.signs = signs.duplicate()
	arm_board(battle.board, signs)


## 盤に効く札の準備。仮縫いのずれ: ポータルの対を 1 つずつずらして組み直す（上の行・左の列から数えて、対 i の 2 つ目を、対 i + 1 の 2 つ目と入れ替える）。
static func arm_board(board: Board, signs: Array[int]) -> void:
	if not signs.has(Sign.SHIFT):
		return
	var pairs := portal_pairs(board)
	if pairs.size() < 2:
		return
	for i in pairs.size():
		var a: Vector2i = pairs[i][0]
		var b: Vector2i = pairs[(i + 1) % pairs.size()][1]
		board.portal_exits[a] = b
		board.portal_exits[b] = a


## ポータルの対の並び（[上の行・左の列にあるほう, もう一方]。対は、1 つ目の読む順）。
static func portal_pairs(board: Board) -> Array[Array]:
	var pairs: Array[Array] = []
	for portal: Vector2i in board.portal_exits:
		var exit: Vector2i = board.portal_exits[portal]
		if Board.in_reading_order(portal, exit):
			pairs.append([portal, exit])
	pairs.sort_custom(func(x: Array, y: Array) -> bool: return Board.in_reading_order(x[0], y[0]))
	return pairs


## 駒 unit に、対戦の札が駒に掛ける能力値の層（射程・巡航の移動力）を付け直す（Battle.add_unit が置くたびに呼ぶ）。
## 札の無い対戦では、層は空（何も変わらない）。
static func equip(battle: Battle, unit: Unit) -> void:
	unit.sign_bonus.clear()
	unit.hazed = battle.signs.has(Sign.HAZE)
	unit.cruise_bonus = GALE_CRUISE if battle.signs.has(Sign.GALE) else 0
	if battle.signs.has(Sign.GLEAM) and UnitKind.role(unit.kind) == UnitKind.Role.REARGUARD:
		unit.sign_bonus[Unit.Stat.ATTACK_RANGE] = GLEAM_RANGE


## 天裂の名残りで縮めたあとの射程（range_value は、ほかの層をすべて足した射程）。
static func hazed_range(range_value: int) -> int:
	return range_value - HAZE_CUT if range_value >= HAZE_FROM else range_value


## 必殺技のゲージにためる量（いつもの量 amount に、札の効き目を掛けたもの）。
static func gauge_gain(battle: Battle, amount: int) -> int:
	if amount > 0 and battle.signs.has(Sign.BRIM):
		return amount * BRIM_PERCENT / 100
	return amount


## ターン 2 からの、結晶泉に中立の駒が湧き直す確率（%）。
static func respawn_percent(battle: Battle) -> int:
	if battle.signs.has(Sign.HUSH):
		return 0
	if battle.signs.has(Sign.LOOSE):
		return LOOSE_RESPAWN_PERCENT
	return Neutral.RESPAWN_CHANCE_PERCENT


## 森にいる駒が受ける攻撃のダメージの割合（%）。
static func forest_rate_percent(battle: Battle) -> int:
	return THICKET_RATE_PERCENT if battle.signs.has(Sign.THICKET) else Combat.FOREST_DAMAGE_RATE_PERCENT


## スキルを使ったあとのクールダウン（スキルの決まりの値 base に、札の効き目を当てたもの）。
static func cooldown_of(battle: Battle, base: int) -> int:
	if battle.signs.has(Sign.TAUT) and base > 1:
		return maxi(1, base - TAUT_CUT)
	return base


static func _has_forest(board: Board) -> bool:
	for y in board.size.y:
		for x in board.size.x:
			if board.terrain_at(Vector2i(x, y)) == Terrain.Type.FOREST:
				return true
	return false
