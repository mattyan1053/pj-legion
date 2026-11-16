extends RefCounted
## ストーリーの話「撃ち合い」（docs/story.md）。MILITARY の物語のチュートリアル（2 / 6）。1 話 1 ファイル。
##
## チュートリアルの話は、1 つの話で 1〜2 個だけ教える（docs/story.md の「チュートリアル」）。
## 部隊は決まっていて（SQUAD）、敵は少なく、まず負けない。教え方は、出撃の準備の文（LESSON）と、対戦の途中の台詞（CUES）。
## **話し手と会話の文は仮のもの**（遊び方を伝える文として書いた。世界と登場人物は、まだ決まっていない。Issue #49）。
## 教えること: 射程（スナイパーは遠くから撃てる）と、前衛・後衛（堅い盾役を前に立てる）。

const Map := preload("res://rules/maps/drill_field.gd")
const StageLook := preload("res://game/stage_look.gd")
const BattleCues := preload("res://game/battle_cues.gd")

const ID := &"drill_sniper"
const TITLE := "撃ち合い"
const LOOK := StageLook.STONE_WALLS
const MAP := Map

## 出撃の準備に出す、この話で覚えること（1 行）。
const LESSON := "スナイパーは 4 マス先から撃てるが、打たれ弱い。盾役を前に立てる。"

## クリアで増えるもの（docs/story.md の「解放」）。
const UNLOCKS: Array[UnitKind.Id] = []

## 人の部隊（決まっている。出撃の準備で選び直さない）: [駒の種類, [装備, …]] の列。
const SQUAD := [
	[UnitKind.Id.SHIELD_TROOPER, []],
	[UnitKind.Id.SNIPER, []],
	[UnitKind.Id.SNIPER, []],
]

const ENEMY_ARMY := UnitKind.Army.FANTASY
const ENEMY := [
	[UnitKind.Id.PALADIN, []],
]

const DEPLOY := [[], []]

const SPEAKERS := ["教官", "演習相手"]
const BEFORE := [
	[0, "スナイパーは 4 マス先まで撃てる。そのかわり打たれ弱い。"],
	[0, "シールドトルーパーを前に立てて、その後ろから撃て。"],
]
const AFTER := [
	[0, "射程を活かせば、撃たれる前に崩せる。"],
]

## 対戦の途中の台詞（docs/story.md の「対戦の途中の会話」）。遊び方を、触っている最中に 1 行ずつ伝える。
const CUES := [
	[BattleCues.TURN, 1, 0, "敵の駒を押すと、敵の届く範囲が見える。その外から撃とう。"],
	[BattleCues.FALLEN, 0, 0, "前に出すぎたな。盾役の後ろへ下がれ。"],
]
