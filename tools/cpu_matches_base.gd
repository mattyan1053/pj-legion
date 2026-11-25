extends SceneTree
## CPU どうしの対戦の集計（tools/cpu_matches.gd）の土台: 読み込み、調整値、引数を読む・部隊を作る・盤を用意する・表を出す道具。
## tools/cpu_matches.gd がこれを継ぐ（集計の流れ _initialize はそちら）。


const CpuMatch := preload("res://tools/cpu_match.gd")
const Story := preload("res://game/story.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const Names := preload("res://game/names.gd")
const VersusFields := preload("res://game/versus_fields.gd")
const Maps := preload("res://game/maps.gd")
const RandomSquad := preload("res://game/random_squad.gd")  # --squads=random の、対戦の部隊（両軍）

const ARMIES: Array[UnitKind.Army] = [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]
const STAGE_NAMES := {
	BoardGenerator.Stage.PLAIN: "1 中央平原",
	BoardGenerator.Stage.LABYRINTH: "2 迷宮回廊",
	BoardGenerator.Stage.TWIN_SPRINGS: "3 双子結晶",
}
## --episode のときの、集計の「マップ」の欄の鍵（生成のマップと重ならない値）。名前は話の名前。
const EPISODE_STAGE := -1
var _episode_title := ""
## --stage に手で作ったマップを選んだときの、集計の「マップ」の欄の鍵。名前はマップの名前。
const MAP_STAGE := -2
var _map_title := ""
## 「両軍とも同じ役割」の編成（--decks=even）。Deck.roster の並び（前衛・後衛・奇襲・回復）の何番目を雇うか。
const EVEN_SLOTS: Array[int] = [0, 0, 1, 1, 2, 3]


## 駒の種類ごとの表（種類 -> [雇った数, 倒された数, 与えたダメージ, 倒した数, 進化した数]）を、1 体あたりで出す。
## kings は、将の行を割る数（将は雇った数が 0 なので、出た局の数で割る）。
func _print_kinds(by_kind: Dictionary, kings: int) -> void:
	var kind_ids := by_kind.keys()
	kind_ids.sort()
	for kind: UnitKind.Id in kind_ids:
		var row: Array = by_kind[kind]
		var count: int = row[0] if row[0] > 0 else kings
		print("  %-12s 雇った %4d 体  倒された %3.0f%%  与えたダメージ %5.1f  倒した %4.2f  進化した %3.0f%%" % [
			Names.kind(kind), row[0], 100.0 * row[1] / count, float(row[2]) / count,
			float(row[3]) / count, 100.0 * row[4] / count,
		])


## 倒された駒の倒され方（種類 -> CpuMatch.Fall の列）を、種類ごとに出す。
## 「何もできずに落ちた」の目安は、与えたダメージが 0 のままと、1 発ぶん（基本の攻撃力）以下のまま。
## 「一撃で」は、ダメージを受けたのが止めの 1 回だけ。止めを刺した駒は、役割ごと（奇襲は、同じフェーズにシャドウステップで跳んでいた数も）。
func _print_falls(falls: Dictionary) -> void:
	var kind_ids := falls.keys()
	kind_ids.sort()
	for kind: UnitKind.Id in kind_ids:
		if UnitKind.role(kind) == UnitKind.Role.HEALER:
			continue
		var total: int = falls[kind].size()
		var silent := 0
		var one_hit := 0
		var one_shot := 0
		var one_shot_by_fresh_raider := 0
		var by_raider := 0
		var by_rearguard := 0
		var by_vanguard := 0
		var after_step := 0
		var turns := 0
		for fall: CpuMatch.Fall in falls[kind]:
			silent += 1 if fall.damage == 0 else 0
			one_hit += 1 if fall.damage <= UnitKind.power(kind) else 0
			one_shot += 1 if fall.hits_taken <= 1 else 0
			turns += fall.turn
			if fall.killer_kind < 0:
				continue
			match UnitKind.role(fall.killer_kind as UnitKind.Id):
				UnitKind.Role.RAIDER:
					by_raider += 1
					after_step += 1 if fall.after_step else 0
					one_shot_by_fresh_raider += 1 if fall.hits_taken <= 1 and fall.killer_level == 1 else 0
				UnitKind.Role.REARGUARD:
					by_rearguard += 1
				UnitKind.Role.VANGUARD:
					by_vanguard += 1
		print("  %-12s 倒された %4d 体（平均ターン %4.1f）  与えたダメージ 0 のまま %3.0f%%  1 発ぶん以下 %3.0f%%  一撃で %3.0f%%（レベル 1 の奇襲の一撃 %3.0f%%）  止め: 奇襲 %3.0f%%（跳んだあと %3.0f%%） 後衛 %3.0f%% 前衛 %3.0f%%" % [
			Names.kind(kind), total, float(turns) / total, 100.0 * silent / total, 100.0 * one_hit / total,
			100.0 * one_shot / total, 100.0 * one_shot_by_fresh_raider / total,
			100.0 * by_raider / total, 100.0 * after_step / total, 100.0 * by_rearguard / total, 100.0 * by_vanguard / total,
		])


## その駒に入った経験値の合計（当たりの経験値が hit のとき）。
func _experience(tally: Array, hit: int) -> int:
	return (
		tally[0] * hit + tally[1] * Growth.DEFEAT_EXPERIENCE
		+ tally[2] * Growth.NEUTRAL_DEFEAT_EXPERIENCE + tally[3] * Growth.HEAL_EXPERIENCE
		+ tally[4] * Growth.MID_BOSS_DEFEAT_EXPERIENCE
	)


func _deck(army: UnitKind.Army, mode: String, rules: DeckRules) -> Deck:
	if mode != "even":
		return CpuDeck.build(army, rules)
	var deck := Deck.new(army, rules)
	var roster := Deck.roster(army)
	for slot in EVEN_SLOTS:
		if rules.allows(army, roster[slot]):
			deck.add(roster[slot])
	return deck


## 部隊の中身を分ける鍵（--squads の「部隊の中身ごとの勝率」）。軍の並びを頭に付ける。
## 駒の種類（入っている部隊）、駒の種類の数、駒の数、装備の数、役割の組み合わせ（前衛・後衛・奇襲・回復の数）、CPU の編成と同じか。
## 軍略（trait_id。無ければ Traits.NONE）と、その軍略と兵種の数の組も。
static func _squad_keys(deck: Deck, army: UnitKind.Army, rival_army: UnitKind.Army, trait_id := Traits.NONE) -> Array[String]:
	var head := "%s 対 %s " % [Names.army(army), Names.army(rival_army)]
	var keys: Array[String] = []
	var counts := {}
	var roles: Array[int] = [0, 0, 0, 0, 0]
	var items := 0
	for entry in deck.entries:
		counts[entry.kind] = counts.get(entry.kind, 0) + 1
		roles[UnitKind.role(entry.kind)] += 1
		items += entry.equipment.size()
	for kind: UnitKind.Id in counts:
		keys.append(head + "駒 %s あり" % Names.kind(kind))
		keys.append(head + "駒 %s %d 体" % [Names.kind(kind), counts[kind]])
	for kind in Deck.roster(army):
		if not counts.has(kind):
			keys.append(head + "駒 %s 0 体" % Names.kind(kind))
	keys.append(head + "数 %d 体" % deck.entries.size())
	keys.append(head + "装備 %d 個" % items)
	keys.append(head + "役割 前%d 後%d 奇%d 回%d" % roles.slice(1))
	if _deck_text(deck) == _deck_text(CpuDeck.build(army, deck.rules)):
		keys.append(head + "CPU の編成と同じ")
	if trait_id != Traits.NONE:
		var name := Names.troop_trait(trait_id)
		keys.append(head + "軍略 %s" % name)
		for kind: UnitKind.Id in counts:
			keys.append(head + "軍略 %s・駒 %s %d 体" % [name, Names.kind(kind), counts[kind]])
	return keys


## --without の駒を抜き、--budget の予算に置き換えた、対戦の決まり。どちらも空なら対戦の決まりそのもの。
## 知らない名前や読めない予算があれば null。
static func _rules_without(names: String, budget_text: String = "") -> DeckRules:
	if names.is_empty() and budget_text.is_empty():
		return DeckRules.versus()
	var removed: Array[UnitKind.Id] = []
	for name in (names.split(",") if not names.is_empty() else PackedStringArray()):
		var index := UnitKind.Id.keys().find(name.to_upper())
		if index == -1:
			return null
		removed.append(UnitKind.Id.values()[index])
	var versus := DeckRules.versus()
	var rosters := {}
	var budgets := {}
	for army in versus.armies():
		rosters[army] = versus.roster(army).filter(func(kind: UnitKind.Id) -> bool: return not removed.has(kind))
		budgets[army] = versus.budget(army)
	if not budget_text.is_empty():
		var parts := budget_text.split(",")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			return null
		budgets[UnitKind.Army.MILITARY] = parts[0].to_int()
		budgets[UnitKind.Army.FANTASY] = parts[1].to_int()
	return DeckRules.new(&"without", versus.max_units, rosters, budgets, versus.items())


## --map のファイルの、文字の格子の行（空の行は飛ばす）。マップのファイルの書式（[rows] の節がある）なら、その節の行。
func _map_rows(path: String) -> PackedStringArray:
	if FileAccess.get_file_as_string(path).contains("[rows]"):
		return (Maps.load_file(path)["map"] as HandMap).rows
	var rows := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().is_empty():
			rows.append(line.strip_edges())
	return rows


## 話 id（ファイルのパスなら、その名前）の話。物語に並んでいなければ null。
func _find_episode(given: String) -> RefCounted:
	var id := StringName(given.get_file().get_basename())
	for each: RefCounted in Story.all_episodes():
		if each.id == id:
			return each
	return null


## --squads=random の、人の側の部隊。その話を初めて遊ぶときに雇える駒から、種で決まる順に、数の上限まで予算の中で雇う。
## 予算と持たせられる装備も、その話を初めて遊ぶときのもの（story.gd の unlocked_before）。
## 並びは役割の順（既定の編成と同じく、前衛が前に置かれる）。装備は既定の編成の決まり（Story.equip_defaults）。
func _random_squad(episode: RefCounted, squad_seed: int) -> Deck:
	var rng := RandomNumberGenerator.new()
	rng.seed = squad_seed
	var given := Story.unlocked_before(episode)
	var kinds := given.kinds
	var deck := Deck.new(given.campaign.army, Story.rules_of(given))
	var hired: Array[UnitKind.Id] = []
	var cost := 0
	while hired.size() < deck.rules.max_units:
		var affordable := kinds.filter(func(kind: UnitKind.Id) -> bool: return cost + UnitKind.cost(kind) <= deck.budget())
		if affordable.is_empty():
			break
		var kind: UnitKind.Id = affordable[rng.randi_range(0, affordable.size() - 1)]
		hired.append(kind)
		cost += UnitKind.cost(kind)
	hired.sort_custom(func(a: UnitKind.Id, b: UnitKind.Id) -> bool: return UnitKind.role(a) < UnitKind.role(b))
	for kind in hired:
		deck.add(kind)
	Story.equip_defaults(deck)
	return deck


func _map_name(stage: int) -> String:
	if stage == EPISODE_STAGE:
		return "話 " + _episode_title
	if stage == MAP_STAGE:
		return _map_title
	return STAGE_NAMES[stage]


static func _deck_text(deck: Deck) -> String:
	var parts: Array[String] = []
	for entry in deck.entries:
		var text := Names.kind(entry.kind)
		for item in entry.equipment:
			text += " + " + Names.item(item)
		parts.append(text)
	return "%s（コスト %d / %d）" % ["、".join(parts), deck.total_cost(), deck.budget()]


## --signs: 縫い目の様子を、めくらずに札 value（鍵を `,` で並べたもの）に決める（測るためだけ）。none なら様子を付けない。
static func _fix_signs(setup: MatchSetup, value: String) -> void:
	if value == "none":
		setup.rules.erase(OptionalRules.SEAM)
		setup.scenario.signs = []
		return
	var problems: Array[String] = []
	setup.scenario.signs = Seam.from_keys(value.split(",", false), problems)
	if not problems.is_empty():
		printerr("--signs の札が読めない: %s" % ", ".join(problems))


## --stronghold: 拠点の場所を、盤の出どころの決めた場所の代わりに試す（測るためだけ）。値は「列,行」（そのマス）か「lean:K」（道のりの寄せ K。
## Board.stronghold_lean）。MatchSetup.create_battle が拠点を置くのと同じ順（砲台のあと）に置き、両方の勝ち方に拠点を足す。
## 置けなければ偽（拠点は置かない）。
static func _arm_trial_stronghold(battle: Battle, value: String, battle_seed: int) -> bool:
	var board := battle.board
	if value.begins_with("lean:"):
		board.stronghold_site = Board.NO_CELL
		board.stronghold_lean = value.trim_prefix("lean:").to_int()
	else:
		var parts := value.split(",")
		board.stronghold_site = Vector2i(parts[0].to_int(), parts[1].to_int())
	Stronghold.arm(board, battle_seed)
	if board.stronghold_cell == Board.NO_CELL:
		return false
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		battle.win_conditions[side].append(GameWonEvent.Reason.STRONGHOLD_HELD)
	return true


## `--名前=値` の引数（`--` のあとに書いたもの）。
func _arguments() -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var parts := argument.trim_prefix("--").split("=", true, 1)
			result[parts[0]] = parts[1]
	return result
