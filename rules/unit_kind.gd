class_name UnitKind
extends RefCounted
## 駒の種類と、種類ごとの基本の能力値。
##
## 種類は「役割（前衛・後衛・奇襲・回復）」と「軍（MILITARY / FANTASY）」の組。
## 将と中立の駒は役割と軍を持たない。
## 魔物（is_monster）は、役割を持ち、軍を持たない。ストーリーの話の敵としてだけ出る（雇えない。どの編成の決まりのロスターにも入らない）。
## 魔物の「コスト」は雇う値ではなく、倒す価値の目安（CPU が倒す相手を選ぶときに読む）。
## 数値は調整値（遊んで直していく）。レベルアップや進化で変わる値は駒（Unit）の側が持つ。

enum Id {
	KING,  ## 将。各陣営に 1 体
	SHIELD_TROOPER,  ## MILITARY・前衛
	SNIPER,  ## MILITARY・後衛
	COMMANDO,  ## MILITARY・奇襲
	MEDIC,  ## MILITARY・回復
	PALADIN,  ## FANTASY・前衛
	SORCERER,  ## FANTASY・後衛
	SPELLBLADE,  ## FANTASY・奇襲
	PRIEST,  ## FANTASY・回復
	MINION,  ## 中立・エナジー・コア
	ELITE_MINION,  ## 中立・エリートミニオン（中ボス）
	SKELETON,  ## 魔物・奇襲。弱く、数で押す
	SKELETON_ARCHER,  ## 魔物・後衛。離れて撃つ
	SKELETON_BRUTE,  ## 魔物・前衛。堅くて遅い
	SKELETON_CALLER,  ## 魔物・後衛。骸骨兵を起こす（骨起こし）
	SKELETON_DRUMMER,  ## 魔物・後衛。周りの味方を突撃させる（骨太鼓）
	SKELETON_BANNER,  ## 魔物・奇襲。倒れると、周りの味方が奮起する（Monsters）
	BAT,  ## 魔物・奇襲。速く脆い。支配領域で止まらず、森を平地と同じに飛ぶ
	FRAY,  ## 魔物・前衛。倒れると、結び目が残り、放っておくと立ち直る（Monsters）
	NEEDLE,  ## 魔物・後衛。動かないが、遠くまで撃つ
	SPIDER,  ## 魔物・奇襲。当てた相手を、次の番まで動けなくする（Monsters）
	EATER,  ## 魔物・前衛。倒れると、腹の糸が弾けて周りを焼く（Monsters）
	CRAB,  ## 魔物・前衛。結晶の殻で、離れた所からの攻撃では狙えない（Monsters）
	SHROOM,  ## 魔物・奇襲。胞子で、周りの敵の攻撃を弱める（Monsters）
}

enum Role { NONE, VANGUARD, REARGUARD, RAIDER, HEALER }
enum Army { NONE, MILITARY, FANTASY }

## power は攻撃力。回復役（衛生兵・プリースト）だけは回復量（回復役の攻撃の強さは HEALER_STRIKE。別の値）。
## [役割, 軍, コスト, 最大 HP, power, 移動力, 射程]。名前は画面の文の表（game/text/names.csv の unit.<id>）。
const _TABLE := {
	Id.KING: [Role.NONE, Army.NONE, 0, 30, 8, 4, 1],
	Id.SHIELD_TROOPER: [Role.VANGUARD, Army.MILITARY, 4, 44, 6, 3, 1],
	Id.SNIPER: [Role.REARGUARD, Army.MILITARY, 3, 13, 7, 3, 4],
	Id.COMMANDO: [Role.RAIDER, Army.MILITARY, 3, 16, 12, 6, 1],
	Id.MEDIC: [Role.HEALER, Army.MILITARY, 3, 20, 15, 4, 1],
	Id.PALADIN: [Role.VANGUARD, Army.FANTASY, 4, 52, 8, 3, 1],
	Id.SORCERER: [Role.REARGUARD, Army.FANTASY, 3, 20, 11, 3, 2],
	Id.SPELLBLADE: [Role.RAIDER, Army.FANTASY, 3, 22, 12, 6, 1],
	Id.PRIEST: [Role.HEALER, Army.FANTASY, 3, 22, 14, 4, 2],
	Id.MINION: [Role.NONE, Army.NONE, 0, 12, 4, 2, 1],
	Id.ELITE_MINION: [Role.NONE, Army.NONE, 0, 50, 10, 2, 2],
	Id.SKELETON: [Role.RAIDER, Army.NONE, 1, 14, 6, 4, 1],
	Id.SKELETON_ARCHER: [Role.REARGUARD, Army.NONE, 2, 12, 6, 3, 3],
	Id.SKELETON_BRUTE: [Role.VANGUARD, Army.NONE, 3, 64, 10, 2, 1],
	Id.SKELETON_CALLER: [Role.REARGUARD, Army.NONE, 3, 18, 5, 3, 2],
	Id.SKELETON_DRUMMER: [Role.REARGUARD, Army.NONE, 3, 22, 5, 3, 2],
	Id.SKELETON_BANNER: [Role.RAIDER, Army.NONE, 2, 26, 6, 3, 1],
	Id.BAT: [Role.RAIDER, Army.NONE, 1, 12, 7, 6, 1],
	Id.FRAY: [Role.VANGUARD, Army.NONE, 2, 30, 6, 2, 1],
	Id.NEEDLE: [Role.REARGUARD, Army.NONE, 2, 28, 8, 0, 4],
	Id.SPIDER: [Role.RAIDER, Army.NONE, 2, 18, 5, 4, 1],
	Id.EATER: [Role.VANGUARD, Army.NONE, 3, 36, 8, 3, 1],
	Id.CRAB: [Role.VANGUARD, Army.NONE, 3, 30, 7, 3, 1],
	Id.SHROOM: [Role.RAIDER, Army.NONE, 2, 20, 5, 3, 1],
}


## 回復役の攻撃の強さ（回復量とは別の値。docs/healer-role.md の「回復役の攻撃」）。射程は回復と同じ。
const MEDIC_STRIKE := 4
const PRIEST_STRIKE := 4
const HEALER_STRIKE := {
	Id.MEDIC: MEDIC_STRIKE,
	Id.PRIEST: PRIEST_STRIKE,
}


static func role(id: Id) -> Role:
	return _TABLE[id][0]


static func army(id: Id) -> Army:
	return _TABLE[id][1]


static func cost(id: Id) -> int:
	return _TABLE[id][2]


static func max_hp(id: Id) -> int:
	return _TABLE[id][3]


static func power(id: Id) -> int:
	return _TABLE[id][4]


## 回復役の攻撃の強さ（HEALER_STRIKE）。回復役でなければ 0。
static func healer_strike(id: Id) -> int:
	return HEALER_STRIKE.get(id, 0)


static func move_range(id: Id) -> int:
	return _TABLE[id][5]


static func attack_range(id: Id) -> int:
	return _TABLE[id][6]


static func is_neutral(id: Id) -> bool:
	return id == Id.MINION or id == Id.ELITE_MINION


## 魔物（軍に属さない、話の敵としてだけ出る駒）か。役割を持ち、軍を持たない種類。
static func is_monster(id: Id) -> bool:
	return army(id) == Army.NONE and role(id) != Role.NONE


## 周り 8 マスに支配領域（ZOC）を作るか。戦線を張る前衛だけ。
static func exerts_zoc(id: Id) -> bool:
	return role(id) == Role.VANGUARD
