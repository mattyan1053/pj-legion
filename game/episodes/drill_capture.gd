extends RefCounted
## ストーリーの話「本陣を取れ」（docs/story.md）。MILITARY の物語のチュートリアル（6 / 6）。1 話 1 ファイル。
##
## チュートリアルの話は、1 つの話で 1〜2 個だけ教える（docs/story.md の「チュートリアル」）。
## 部隊は決まっていて（SQUAD）、敵は少なく、まず負けない。教え方は、出撃の準備の文（LESSON）と、対戦の途中の台詞（CUES）。
## **話し手と会話の文は仮のもの**（遊び方を伝える文として書いた。世界と登場人物は、まだ決まっていない。Issue #49）。
## 教えること: 本陣の占拠（敵の本陣に乗り続けて勝つ）。この話は、敵の将を倒しても終わらない（WINS）。

const Map := preload("res://rules/maps/drill_field.gd")
const StageLook := preload("res://game/stage_look.gd")
const BattleCues := preload("res://game/battle_cues.gd")

const ID := &"drill_capture"
const TITLE := "本陣を取れ"
const LOOK := StageLook.STONE_WALLS
const MAP := Map

## 出撃の準備に出す、この話で覚えること（1 行）。
const LESSON := "敵の本陣のマスに 3 ターン乗り続ければ勝ち。この演習は、将を倒しても終わらない。"

## クリアで増えるもの（docs/story.md の「解放」）。
const UNLOCKS: Array[UnitKind.Id] = []

## 人の勝ち方は本陣の占拠だけ（敵の将を倒しても終わらない）。
const WINS: Array[GameWonEvent.Reason] = [GameWonEvent.Reason.HQ_CAPTURED]

## 人の部隊（決まっている。出撃の準備で選び直さない）: [駒の種類, [装備, …]] の列。
const SQUAD := [
	[UnitKind.Id.SHIELD_TROOPER, []],
	[UnitKind.Id.SHIELD_TROOPER, []],
	[UnitKind.Id.SNIPER, []],
	[UnitKind.Id.SNIPER, []],
	[UnitKind.Id.MEDIC, []],
]

const ENEMY_ARMY := UnitKind.Army.FANTASY
const ENEMY := [
	[UnitKind.Id.PALADIN, []],
	[UnitKind.Id.SORCERER, []],
]

const DEPLOY := [[], []]

const SPEAKERS := ["教官", "演習相手"]
const BEFORE := [
	[0, "敵の本陣のマスに、3 ターン続けて乗っていれば勝ちだ。"],
	[0, "この演習では、将を倒しても終わらない。本陣を取れ。"],
]
const AFTER := [
	[0, "演習はここまでだ。実戦へ向かうぞ。"],
]

## 対戦の途中の台詞（docs/story.md の「対戦の途中の会話」）。遊び方を、触っている最中に 1 行ずつ伝える。
const CUES := [
	[BattleCues.TURN, 1, 0, "本陣は、敵の将の足元のマスだ。周りを片付けて乗り込め。"],
	[BattleCues.KING_HALF, 1, 0, "将を倒しても終わらない。本陣のマスに乗り続けろ。"],
]
