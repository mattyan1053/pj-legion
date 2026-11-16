extends RefCounted
## ストーリーの物語「MILITARY の物語」（docs/story.md の「物語」）。1 物語 1 ファイル。物語の並びは story.gd の CAMPAIGNS。
##
## 物語は、軍 1 つと話の列。人はこの軍で話を進め、話をクリアすると、この軍の駒が雇えるようになる。
## **名前と中身は仮のもの。** 世界と登場人物は、まだ決まっていない（Issue #49）。

## 物語の id（クリアの記録に書く。変えると、記録が外れる）。
const ID := &"military"
## 物語を選ぶ画面に出す名前。
const TITLE := "MILITARY の物語"
## 人が使う軍。
const ARMY := UnitKind.Army.MILITARY
## この物語の部隊の編成の決まりの名前（取っておく部隊に書く）。最初の物語なので、物語が 1 つだったころの名前のまま。
const RULES_ID := &"story"
## 最初から雇える駒の種類（この物語の軍の駒）。ほかは、話をクリアすると増える（話のデータの UNLOCKS）。
## 最初の 6 話（チュートリアル）は部隊が決まっているので、ここから組むのは本編（尾根の小道）から。
const STARTING_KINDS: Array[UnitKind.Id] = [UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SNIPER]
## 最初から持たせられる装備。ほかは、話をクリアすると増える（話のデータの UNLOCK_ITEMS）。
const STARTING_ITEMS: Array[Equipment.Id] = []
## 最初の部隊のコストの上限。話をクリアすると上がる（話のデータの BUDGET_UP）。対戦の予算（24）より低く始め、物語の終わりには超える。
const STARTING_BUDGET := 20

## 話の並び（一本道。game/episodes/ の 1 ファイルが 1 話）。
## 頭の 6 話はチュートリアル（1 つの話で 1〜2 個だけ教える。docs/story.md の「チュートリアル」）、そのあとが本編。
const EPISODES: Array[Script] = [
	preload("res://game/episodes/drill_first_steps.gd"),
	preload("res://game/episodes/drill_sniper.gd"),
	preload("res://game/episodes/drill_medic.gd"),
	preload("res://game/episodes/drill_skills.gd"),
	preload("res://game/episodes/drill_shrine.gd"),
	preload("res://game/episodes/drill_capture.gd"),
	preload("res://game/episodes/ridge_path.gd"),
	preload("res://game/episodes/ridge_ambush.gd"),
	preload("res://game/episodes/ridge_hold.gd"),
	preload("res://game/episodes/gorge_rout.gd"),
]
