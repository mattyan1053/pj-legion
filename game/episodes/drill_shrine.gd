extends RefCounted
## ストーリーの話「結晶の番人」（docs/story.md）。MILITARY の物語のチュートリアル（5 / 6）。1 話 1 ファイル。
##
## チュートリアルの話は、1 つの話で 1〜2 個だけ教える（docs/story.md の「チュートリアル」）。
## 部隊は決まっていて（SQUAD）、敵は少なく、まず負けない。教え方は、出撃の準備の文（LESSON）と、対戦の途中の台詞（CUES）。
## **話し手と会話の文は仮のもの**（遊び方を伝える文として書いた。世界と登場人物は、まだ決まっていない。Issue #49）。
## 教えること: 中立の駒（結晶泉から湧く）と、中ボスを倒して得る聖遺物。

const Map := preload("res://rules/maps/shrine_hollow.gd")
const StageLook := preload("res://game/stage_look.gd")
const BattleCues := preload("res://game/battle_cues.gd")

const ID := &"drill_shrine"
const TITLE := "結晶の番人"
const LOOK := StageLook.CRYSTAL_FOREST
const MAP := Map

## 出撃の準備に出す、この話で覚えること（1 行）。
const LESSON := "結晶泉から湧く中立の駒は、どちらも襲う。中ボスを倒すと聖遺物が手に入る。"

## クリアで増えるもの（docs/story.md の「解放」）。
const UNLOCKS: Array[UnitKind.Id] = []

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
	[UnitKind.Id.SORCERER, []],
	[UnitKind.Id.PRIEST, []],
]

const DEPLOY := [[], []]

const SPEAKERS := ["教官", "演習相手"]
const BEFORE := [
	[0, "結晶泉からは中立の駒が湧き、どちらの軍も襲う。"],
	[0, "大きな番人（中ボス）を倒せば、聖遺物で部隊が強くなる。"],
]
const AFTER := [
	[0, "番人に挑むかどうかも、戦いの駆け引きだ。"],
]

## 対戦の途中の台詞（docs/story.md の「対戦の途中の会話」）。遊び方を、触っている最中に 1 行ずつ伝える。
const CUES := [
	[BattleCues.TURN, 1, 0, "こちらの本陣に近い番人を狙え。数で囲めば倒せる。"],
	[BattleCues.RELIC, 0, 0, "聖遺物を得た。必殺技のゲージも大きくたまる。"],
]
