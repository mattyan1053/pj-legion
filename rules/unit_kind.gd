class_name UnitKind
extends RefCounted
## 駒の種類と、種類ごとの基本の能力値。
##
## 種類は「役割（前衛・後衛・奇襲・回復）」と「軍（MILITARY / FANTASY）」の組。
## 将と中立の駒は役割と軍を持たない。
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
}

enum Role { NONE, VANGUARD, REARGUARD, RAIDER, HEALER }
enum Army { NONE, MILITARY, FANTASY }

## power は攻撃力。回復役（衛生兵・プリースト）だけは回復量。
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


static func move_range(id: Id) -> int:
	return _TABLE[id][5]


static func attack_range(id: Id) -> int:
	return _TABLE[id][6]


static func is_neutral(id: Id) -> bool:
	return id == Id.MINION or id == Id.ELITE_MINION


## 周り 8 マスに支配領域（ZOC）を作るか。戦線を張る前衛だけ。
static func exerts_zoc(id: Id) -> bool:
	return role(id) == Role.VANGUARD
