extends RefCounted
## ストーリーの話「尾根の待ち伏せ」（docs/story.md）。1 話 1 ファイル。話の並びは story.gd の EPISODES。
##
## **会話の文は仮のもの。** ストーリーの中身（世界、登場人物）は、まだ決まっていない（Issue #49）。
##
## 1 話と同じマップ「尾根の小道」（rules/maps/ridge_path.gd）を、初期位置を変えて使い回す（Issue #49 の「マップの使い回し」）。
## 敵は本陣の前ではなく、尾根の中ほど（中央の岩の上側）に陣取って始まる。左右どちらの道へも、すぐ出られる。
## 人はいつもの「本陣の前」から。敵の部隊は 1 話より少し強い（docs/story.md の「敵の強さ」）。

const RidgePath := preload("res://rules/maps/ridge_path.gd")
const StageLook := preload("res://game/stage_look.gd")
const BattleCues := preload("res://game/battle_cues.gd")

## 話の id（クリアの記録に書く。変えると、記録が外れる）。
const ID := &"ridge_ambush"
## 会話の見出しに出す名前。
const TITLE := "尾根の待ち伏せ"
## 盤の見た目（1 話と同じ）。
const LOOK := StageLook.LABYRINTH
const MAP := RidgePath

## クリアで新しく雇えるようになる駒の種類（docs/story.md の「駒の解放」）。ほかの軍の駒も解放できる。
const UNLOCKS: Array[UnitKind.Id] = [UnitKind.Id.PALADIN]

## 敵の軍（人の軍は、ストーリーで 1 つ。story.gd の ARMY）。
const ENEMY_ARMY := UnitKind.Army.FANTASY
## 敵の部隊（将を除く）: [駒の種類, [装備, …]] の列。並びの順に、初期位置（DEPLOY）のマスへ置く。
const ENEMY := [
	[UnitKind.Id.PALADIN, [Equipment.Id.IRON_SHIELD, Equipment.Id.IRON_SHIELD]],
	[UnitKind.Id.SORCERER, []],
	[UnitKind.Id.SORCERER, []],
	[UnitKind.Id.PRIEST, []],
]

## 初期位置（将でない駒を置くマスの列）: [プレイヤー1, プレイヤー2]。空なら、いつもの「本陣の前」。
## 敵は中央の岩の上側に横 1 列（真ん中、左右）と、左右の道の入り口。将は本陣（いつも本陣）。
const DEPLOY := [
	[],
	[Vector2i(8, 9), Vector2i(5, 9), Vector2i(11, 9), Vector2i(3, 11), Vector2i(13, 11), Vector2i(8, 7)],
]

## 話し手: 会話の行の side（0 = 人の軍、1 = 敵の軍。名前の札の色）と名前。
const HUMAN_LEADER := "隊長"
const ENEMY_LEADER := "騎士団長"

## 対戦の前と後の会話: [side, 文] の列。話し手の名前は side で決まる（SPEAKERS）。
const SPEAKERS := [HUMAN_LEADER, ENEMY_LEADER]
const BEFORE := [
	[1, "待っていたぞ。今度は尾根の真ん中で迎え撃つ。"],
	[0, "先回りされたか。敵はもう、道の中ほどにいる。"],
	[0, "左右どちらの道からも来られる。本陣を空けるな。"],
	[1, "前のようにはいかない。"],
]
const AFTER := [
	[1, "……これほどとは。我らの盾を、貸そう。"],
	[0, "心強い。谷へ急ごう。"],
]


## 対戦の途中の会話（docs/story.md の「対戦の途中の会話」）: [きっかけ, 値, 話し手（0 か 1）, 文] の列。きっかけは battle_cues.gd。
const CUES := [
	[BattleCues.TURN, 1, 1, "かかったな。尾根の上から挟み込め。"],
	[BattleCues.FALLEN, 0, 0, "一人やられた。固まって進め。"],
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
