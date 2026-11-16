extends RefCounted
## ストーリーの話「尾根の籠城」（docs/story.md）。1 話 1 ファイル。話の並びは story.gd の EPISODES。
##
## **会話の文は仮のもの。** ストーリーの中身（世界、登場人物）は、まだ決まっていない（Issue #49）。
##
## 1・2 話と同じマップ「尾根の小道」（rules/maps/ridge_path.gd）を、勝ち方を変えて使い回す（Issue #49 の「マップの使い回し」）。
## 人は守る側: 決められたターンが終わるまで、将と本陣を守り切れば勝ち（HOLD_TURNS。docs/win-conditions.md の「守り切る」）。
## 敵は数で押す。尾根の中ほどから始まり、いつもの勝ち方（将の撃破、本陣の占拠）で攻めてくる。

const RidgePath := preload("res://rules/maps/ridge_path.gd")
const StageLook := preload("res://game/stage_look.gd")
const BattleCues := preload("res://game/battle_cues.gd")

## 話の id（クリアの記録に書く。変えると、記録が外れる）。
const ID := &"ridge_hold"
## 会話の見出しに出す名前。
const TITLE := "尾根の籠城"
## 盤の見た目（1 話と同じ）。
const LOOK := StageLook.LABYRINTH
const MAP := RidgePath

## クリアで新しく雇えるようになる駒の種類（docs/story.md の「駒の解放」）。
const UNLOCKS: Array[UnitKind.Id] = []

## 人の側（プレイヤー1）が守り切るターン数。このターンが終わるまで決着しなければ、人の勝ち。
const HOLD_TURNS := 10

## 敵の軍（人の軍は、ストーリーで 1 つ。story.gd の ARMY）。
const ENEMY_ARMY := UnitKind.Army.FANTASY
## 敵の部隊（将を除く）: [駒の種類, [装備, …]] の列。並びの順に、初期位置（DEPLOY）のマスへ置く。
const ENEMY := [
	[UnitKind.Id.PALADIN, [Equipment.Id.IRON_SHIELD]],
	[UnitKind.Id.PALADIN, [Equipment.Id.IRON_SHIELD]],
	[UnitKind.Id.SORCERER, []],
	[UnitKind.Id.SORCERER, []],
	[UnitKind.Id.SPELLBLADE, []],
	[UnitKind.Id.SPELLBLADE, []],
	[UnitKind.Id.PRIEST, []],
	[UnitKind.Id.SORCERER, []],
	[UnitKind.Id.SORCERER, []],
]

## 初期位置（将でない駒を置くマスの列）: [プレイヤー1, プレイヤー2]。空なら、いつもの「本陣の前」。
## 敵は尾根の中ほど: 中央の岩の上側に 2 列と、左右の道の入り口。
const DEPLOY := [
	[],
	[
		Vector2i(8, 9), Vector2i(5, 9), Vector2i(11, 9), Vector2i(3, 11), Vector2i(13, 11),
		Vector2i(8, 7), Vector2i(6, 7), Vector2i(10, 7), Vector2i(8, 5),
	],
]

## 話し手: 会話の行の side（0 = 人の軍、1 = 敵の軍。名前の札の色）と名前。
const HUMAN_LEADER := "隊長"
const ENEMY_LEADER := "追撃隊長"

## 対戦の前と後の会話: [side, 文] の列。話し手の名前は side で決まる（SPEAKERS）。
const SPEAKERS := [HUMAN_LEADER, ENEMY_LEADER]
const BEFORE := [
	[0, "追っ手だ。数が多すぎる。"],
	[0, "援軍が着くまで、ここを守り切る。本陣を空けるな。"],
	[1, "尾根ごと押しつぶしてやれ。"],
]
const AFTER := [
	[0, "……持ちこたえた。援軍の旗が見える。"],
	[1, "退け。今日はここまでだ。"],
	[0, "追っ手の残りは、谷の手前の渓谷へ逃げた。"],
]


## 対戦の途中の会話（docs/story.md の「対戦の途中の会話」）: [きっかけ, 値, 話し手（0 か 1）, 文] の列。きっかけは battle_cues.gd。
const CUES := [
	[BattleCues.TURN, 8, 0, "援軍まで、あと 3 ターンだ。持ちこたえろ。"],
	[BattleCues.TURN, 10, 1, "これが最後だ。全員で押し込め。"],
]

## 敵の部隊（決め打ち。編成の決まりの検査は通さない。docs/scenario.md）。
static func enemy_deck() -> Deck:
	var deck := Deck.new(ENEMY_ARMY)
	for row: Array in ENEMY:
		var entry := DeckEntry.new(row[0])
		for item: Equipment.Id in row[1]:
			entry.equip(item)
		deck.entries.append(entry)
	return deck
