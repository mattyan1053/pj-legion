extends RefCounted
## ストーリーの話「手当て」（docs/story.md）。MILITARY の物語のチュートリアル（3 / 6）。1 話 1 ファイル。
##
## チュートリアルの話は、1 つの話で 1〜2 個だけ教える（docs/story.md の「チュートリアル」）。
## 部隊は決まっていて（SQUAD）、敵は少なく、まず負けない。教え方は、出撃の準備の文（LESSON）と、対戦の途中の台詞（CUES）。
## **話し手と会話の文は仮のもの**（遊び方を伝える文として書いた。世界と登場人物は、まだ決まっていない。Issue #49）。
## 教えること: 衛生兵の回復と、回復の泉。クリアで衛生兵を雇えるようになる。

const Map := preload("res://rules/maps/drill_field.gd")
const StageLook := preload("res://game/stage_look.gd")
const BattleCues := preload("res://game/battle_cues.gd")

const ID := &"drill_medic"
const TITLE := "手当て"
const LOOK := StageLook.STONE_WALLS
const MAP := Map

## 出撃の準備に出す、この話で覚えること（1 行）。
const LESSON := "衛生兵は味方を回復する。回復の泉の上で番を迎えた駒も HP が戻る。"

## クリアで増えるもの（docs/story.md の「解放」）。
const UNLOCKS: Array[UnitKind.Id] = [UnitKind.Id.MEDIC]

## 人の部隊（決まっている。出撃の準備で選び直さない）: [駒の種類, [装備, …]] の列。
const SQUAD := [
	[UnitKind.Id.SHIELD_TROOPER, []],
	[UnitKind.Id.SNIPER, []],
	[UnitKind.Id.MEDIC, []],
]

const ENEMY_ARMY := UnitKind.Army.FANTASY
const ENEMY := [
	[UnitKind.Id.SORCERER, []],
]

const DEPLOY := [[], []]

const SPEAKERS := ["教官", "演習相手"]
const BEFORE := [
	[0, "今日は衛生兵を連れていく。傷ついた味方を回復できる。"],
	[0, "回復の泉の上で番を迎えた駒も、HP が戻る。"],
]
const AFTER := [
	[0, "手当てができれば、粘り強く戦える。"],
]

## 対戦の途中の台詞（docs/story.md の「対戦の途中の会話」）。遊び方を、触っている最中に 1 行ずつ伝える。
const CUES := [
	[BattleCues.TURN, 2, 0, "緑のマスの味方を押せば、衛生兵が回復する。"],
	[BattleCues.KING_HALF, 0, 0, "将が弱った。泉のマスへ下げて立て直せ。"],
]
