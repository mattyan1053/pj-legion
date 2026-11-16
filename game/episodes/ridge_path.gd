extends RefCounted
## ストーリーの話「尾根の小道」（docs/story.md）。1 話 1 ファイル。話の並びは story.gd の EPISODES。
##
## **会話の文は仮のもの。** ストーリーの中身（世界、登場人物）は、まだ決まっていない（Issue #49）。
## 話の形（会話 → 対戦 → 会話）を見せるための短い文で、中身が決まったら全部差し替える。
##
## 対戦は手で作ったマップ「尾根の小道」（rules/maps/ridge_path.gd）。人はプレイヤー1（先手、ストーリーの部隊）、
## 敵はプレイヤー2（FANTASY、ENEMY の決め打ちの部隊。CPU が動かす）。
## 敵の部隊は「ふつうに遊べば勝てるが、雑に突っ込むと負ける」くらいを狙い、人の側を CPU に持たせた対戦の勝率で決めた（docs/story.md）。

const RidgePath := preload("res://rules/maps/ridge_path.gd")
const StageLook := preload("res://game/stage_look.gd")
const BattleCues := preload("res://game/battle_cues.gd")

## 話の id（クリアの記録に書く。変えると、記録が外れる）。
const ID := &"ridge_path"
## 会話の見出しに出す名前。
const TITLE := "尾根の小道"
## 盤の見た目（stage_look.gd の THEMES の鍵）。岩の尾根が壁のように続くので、石の壁の見た目にした。
const LOOK := StageLook.STONE_WALLS
const MAP := RidgePath

## クリアで新しく雇えるようになる駒の種類（docs/story.md の「駒の解放」）。
const UNLOCKS: Array[UnitKind.Id] = [UnitKind.Id.COMMANDO]

## 敵の軍（人の軍は、ストーリーで 1 つ。story.gd の ARMY）。
const ENEMY_ARMY := UnitKind.Army.FANTASY
## 敵の部隊（将を除く）: [駒の種類, [装備, …]] の列。並びの順に、本陣の前へ置く（いつもの置き方）。
const ENEMY := [
	[UnitKind.Id.PALADIN, []],
	[UnitKind.Id.SORCERER, []],
]

## 初期位置（将でない駒を置くマスの列）: [プレイヤー1, プレイヤー2]。空なら、いつもの「本陣の前」。
const DEPLOY := [[], []]

## 話し手: 会話の行の side（0 = 人の軍、1 = 敵の軍。名前の札の色）と名前。
const HUMAN_LEADER := "隊長"
const ENEMY_LEADER := "騎士団長"

## 対戦の前と後の会話: [side, 文] の列。話し手の名前は side で決まる（SPEAKERS）。
const SPEAKERS := [HUMAN_LEADER, ENEMY_LEADER]
const BEFORE := [
	[0, "この尾根を越えれば、谷へ下りられる。"],
	[1, "ここから先へは通さない。引き返せ。"],
	[0, "道は左右の 2 本。真ん中の岩は越えられない。"],
	[0, "相手の将を倒すか、相手の本陣を取り続ければ、こちらの勝ちだ。"],
	[1, "来るなら来い。"],
]
const AFTER := [
	[1, "……見事だ。道を空けよう。"],
	[0, "先を急ごう。谷はまだ遠い。"],
	[0, "……だが、あの騎士たちは、まだ尾根にいる。"],
]


## 対戦の途中の会話（docs/story.md の「対戦の途中の会話」）: [きっかけ, 値, 話し手（0 か 1）, 文] の列。きっかけは battle_cues.gd。
const CUES := [
	[BattleCues.KING_HALF, 1, 1, "まだだ。この程度で道は譲らん。"],
]
