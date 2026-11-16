extends RefCounted
## ストーリーの話「スキルと必殺技」（docs/story.md）。MILITARY の物語のチュートリアル（4 / 6）。1 話 1 ファイル。
##
## チュートリアルの話は、1 つの話で 1〜2 個だけ教える（docs/story.md の「チュートリアル」）。
## 部隊は決まっていて（SQUAD）、敵は少なく、まず負けない。教え方は、出撃の準備の文（LESSON）と、対戦の途中の台詞（CUES）。
## **話し手と会話の文は仮のもの**（遊び方を伝える文として書いた。世界と登場人物は、まだ決まっていない。Issue #49）。
## 教えること: 駒ごとのスキルと、軍の必殺技（ゲージがたまる手前から始める）。クリアでアイアンシールドを持たせられるようになる。

const Map := preload("res://rules/maps/drill_field.gd")
const StageLook := preload("res://game/stage_look.gd")
const BattleCues := preload("res://game/battle_cues.gd")

const ID := &"drill_skills"
const TITLE := "スキルと必殺技"
const LOOK := StageLook.STONE_WALLS
const MAP := Map

## 出撃の準備に出す、この話で覚えること（1 行）。
const LESSON := "駒ごとのスキルと、ゲージをためて使う軍の必殺技。"

## クリアで増えるもの（docs/story.md の「解放」）。
const UNLOCKS: Array[UnitKind.Id] = []

const UNLOCK_ITEMS: Array[Equipment.Id] = [Equipment.Id.IRON_SHIELD]
## 人の必殺技のゲージを、この量から始める（いっぱいは 1000）。数ターン戦えば、必殺技が使えるようになる。
const START_GAUGE := 800

## 人の部隊（決まっている。出撃の準備で選び直さない）: [駒の種類, [装備, …]] の列。
const SQUAD := [
	[UnitKind.Id.SHIELD_TROOPER, []],
	[UnitKind.Id.SNIPER, []],
	[UnitKind.Id.SNIPER, []],
	[UnitKind.Id.MEDIC, []],
]

const ENEMY_ARMY := UnitKind.Army.FANTASY
const ENEMY := [
	[UnitKind.Id.PALADIN, [Equipment.Id.IRON_SHIELD]],
	[UnitKind.Id.SORCERER, []],
	[UnitKind.Id.PRIEST, []],
]

const DEPLOY := [[], []]

const SPEAKERS := ["教官", "演習相手"]
const BEFORE := [
	[0, "どの駒にも、スキルが 1 つある。駒のメニューから使える。"],
	[0, "盾役は盾を置き、スナイパーは構えて次の一発を重くする。"],
]
const AFTER := [
	[0, "切り札は、ここぞという時に使え。"],
	[0, "盾を持たせる許しも出た。部隊を組むときに使え。"],
]

## 対戦の途中の台詞（docs/story.md の「対戦の途中の会話」）。遊び方を、触っている最中に 1 行ずつ伝える。
const CUES := [
	[BattleCues.TURN, 1, 0, "メニューの「スキル」を押すと、使えるマスが紫になる。"],
	[BattleCues.ULT_READY, 0, 0, "ゲージがたまった。右下の必殺技で、全員を奮い立たせろ。"],
]
