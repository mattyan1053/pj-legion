extends RefCounted
## ストーリーの物語「FANTASY の物語」（docs/story.md の「物語」）。1 物語 1 ファイル。物語の並びは story.gd の CAMPAIGNS。
##
## **準備中。** 話がまだ無い（EPISODES が空）ので、物語を選ぶ画面では「準備中」の札で、選べない。
## 話を足すと、そのまま遊べる（game/episodes/ に話のファイルを置き、EPISODES に並べる）。

const ID := &"fantasy"
const TITLE := "FANTASY の物語"
const ARMY := UnitKind.Army.FANTASY
const RULES_ID := &"story_fantasy"
const STARTING_KINDS: Array[UnitKind.Id] = [UnitKind.Id.PALADIN, UnitKind.Id.SORCERER, UnitKind.Id.PRIEST]

const EPISODES: Array[Script] = []
