extends RefCounted
## ストーリーの話「渓谷の掃討」（docs/story.md）。1 話 1 ファイル。話の並びは story.gd の EPISODES。
##
## **会話の文は仮のもの。** ストーリーの中身（世界、登場人物）は、まだ決まっていない（Issue #49）。
##
## 2 つ目の手で作ったマップ「結晶の渓谷」（rules/maps/crystal_gorge.gd）。見た目は双子結晶（結晶の森）のテーマ。
## 人の勝ち方は「敵を全滅させる」だけ（WINS。docs/win-conditions.md の「全滅させる」）。敵の将を倒しても、残りの駒を倒しきるまで終わらない。
## 敵はいつもの勝ち方（将の撃破、本陣の占拠）で攻めてくる。

const CrystalGorge := preload("res://rules/maps/crystal_gorge.gd")
const StageLook := preload("res://game/stage_look.gd")
const BattleCues := preload("res://game/battle_cues.gd")

## 話の id（クリアの記録に書く。変えると、記録が外れる）。
const ID := &"gorge_rout"
## 会話の見出しに出す名前。
const TITLE := "渓谷の掃討"
## 盤の見た目。結晶の岩と光る森の、双子結晶のテーマ。
const LOOK := StageLook.CRYSTAL_FOREST
const MAP := CrystalGorge

## クリアで新しく雇えるようになる駒の種類（docs/story.md の「駒の解放」）。
const UNLOCKS: Array[UnitKind.Id] = [UnitKind.Id.SORCERER]

## 人の側（プレイヤー1）の勝ち方（GameWonEvent.Reason の列）。無い話は、いつもの勝ち方（将の撃破、本陣の占拠）。
const WINS: Array[GameWonEvent.Reason] = [GameWonEvent.Reason.ROUTED]

## 敵の軍（人の軍は、ストーリーで 1 つ。story.gd の ARMY）。
const ENEMY_ARMY := UnitKind.Army.FANTASY
## 敵の部隊（将を除く）: [駒の種類, [装備, …]] の列。並びの順に、初期位置（DEPLOY）のマスへ置く。
const ENEMY := [
	[UnitKind.Id.PALADIN, [Equipment.Id.IRON_SHIELD]],
	[UnitKind.Id.SORCERER, []],
	[UnitKind.Id.SPELLBLADE, []],
	[UnitKind.Id.PRIEST, []],
]

## 初期位置（将でない駒を置くマスの列）: [プレイヤー1, プレイヤー2]。空なら、いつもの「本陣の前」。
const DEPLOY := [[], []]

## 話し手: 会話の行の side（0 = 人の軍、1 = 敵の軍。名前の札の色）と名前。
const HUMAN_LEADER := "隊長"
const ENEMY_LEADER := "追撃隊長"

## 対戦の前と後の会話: [side, 文] の列。話し手の名前は side で決まる（SPEAKERS）。
const SPEAKERS := [HUMAN_LEADER, ENEMY_LEADER]
const BEFORE := [
	[0, "追っ手は、結晶の渓谷に逃げ込んだ。"],
	[0, "一人でも逃せば、また追ってくる。残らず倒す。"],
	[0, "裂け目を渡るのは、両端の橋か、真ん中の門だ。"],
	[1, "しつこい連中だ。ここで迎え撃つ。"],
]
const AFTER := [
	[1, "……ここまでか。"],
	[0, "追っ手は片付いた。谷へ下りよう。"],
	[0, "（ここまでが 4 話。続きは、まだ無い）"],
]


## 対戦の途中の会話（docs/story.md の「対戦の途中の会話」）: [きっかけ, 値, 話し手（0 か 1）, 文] の列。きっかけは battle_cues.gd。
const CUES := [
	[BattleCues.FALLEN, 1, 1, "一人やられたか。散るな、固まって迎え撃て。"],
	[BattleCues.KING_HALF, 1, 0, "隊長格は弱っている。だが、残りも逃がすな。"],
]
