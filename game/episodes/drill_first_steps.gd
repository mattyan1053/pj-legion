extends RefCounted
## ストーリーの話「はじめの一歩」（docs/story.md）。MILITARY の物語のチュートリアル（1 / 6）。1 話 1 ファイル。
##
## チュートリアルの話は、1 つの話で 1〜2 個だけ教える（docs/story.md の「チュートリアル」）。
## 部隊は決まっていて（SQUAD）、敵は少なく、まず負けない。教え方は、出撃の準備の文（LESSON）と、対戦の途中の台詞（CUES）。
## **話し手と会話の文は仮のもの**（遊び方を伝える文として書いた。世界と登場人物は、まだ決まっていない。Issue #49）。
## 教えること: 駒を動かして、敵を攻撃する。敵の将を倒せば勝ち。

const Map := preload("res://rules/maps/drill_field.gd")
const StageLook := preload("res://game/stage_look.gd")
const BattleCues := preload("res://game/battle_cues.gd")

const ID := &"drill_first_steps"
const TITLE := "はじめの一歩"
const LOOK := StageLook.STONE_WALLS
const MAP := Map

## 出撃の準備に出す、この話で覚えること（1 行）。
const LESSON := "駒を押して動かし、隣の敵を攻撃する。敵の将を倒せば勝ち。"

## クリアで増えるもの（docs/story.md の「解放」）。
const UNLOCKS: Array[UnitKind.Id] = []

## 人の部隊（決まっている。出撃の準備で選び直さない）: [駒の種類, [装備, …]] の列。
const SQUAD := [
	[UnitKind.Id.SHIELD_TROOPER, []],
	[UnitKind.Id.SHIELD_TROOPER, []],
]

const ENEMY_ARMY := UnitKind.Army.FANTASY
const ENEMY := [
	[UnitKind.Id.SORCERER, []],
]

const DEPLOY := [[], []]

const SPEAKERS := ["教官", "演習相手"]
const BEFORE := [
	[0, "演習を始める。まずは駒の動かし方からだ。"],
	[0, "敵の将を倒せば、こちらの勝ちになる。"],
]
const AFTER := [
	[0, "いい動きだ。次は、離れた所からの撃ち合いを覚えよう。"],
]

## 対戦の途中の台詞（docs/story.md の「対戦の途中の会話」）。遊び方を、触っている最中に 1 行ずつ伝える。
const CUES := [
	[BattleCues.TURN, 1, 0, "自分の駒を押すと、動ける青いマスが出る。"],
	[BattleCues.TURN, 2, 0, "敵の隣で、赤いマスの敵を押せば攻撃だ。"],
	[BattleCues.FALLEN, 1, 0, "よし。残るは敵の将だ。"],
]
