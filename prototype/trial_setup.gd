extends RefCounted
## 試作の対戦の準備（仮）。盤面を作り、決め打ちの編成を両方の本陣の周りに置く。
##
## 編成の画面ができたら、編成のルール（Deck、Deployment）につなぐ。いまは予算を見ない決め打ち。
## ここはノードに依存しない（テストから呼べる）。

## 陣営ごとの編成。将は 1 体目。OFFSETS と同じ並び。
const ARMIES := {
	Unit.Side.PLAYER1: [
		UnitKind.Id.KING,
		UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SHIELD_TROOPER,
		UnitKind.Id.SNIPER, UnitKind.Id.SNIPER,
		UnitKind.Id.COMMANDO, UnitKind.Id.MEDIC,
	],
	Unit.Side.PLAYER2: [
		UnitKind.Id.KING,
		UnitKind.Id.PALADIN, UnitKind.Id.PALADIN,
		UnitKind.Id.SORCERER, UnitKind.Id.SORCERER,
		UnitKind.Id.SPELLBLADE, UnitKind.Id.PRIEST,
	],
}

## 本陣から見た位置（プレイヤー1 の向き。y が負のほうが敵側）。プレイヤー2 は点対称に置く。
## どれも本陣の周り 3 マス以内なので、盤面の生成が障害物を置かない。
##   . 前 . 前 .
##   奇 後 . 後 回
##   . . 将 . .
const OFFSETS: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(-1, -2), Vector2i(1, -2),
	Vector2i(-1, -1), Vector2i(1, -1),
	Vector2i(-2, -1), Vector2i(2, -1),
]


## 盤面を作れないステージ・大きさなら null。
static func create(stage: BoardGenerator.Stage, map_seed: int) -> Battle:
	var board := BoardGenerator.generate(stage, map_seed)
	if board == null:
		return null
	var battle := Battle.new(board, map_seed)
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		var hq := board.hq_cells[side]
		var kinds: Array = ARMIES[side]
		for i in kinds.size():
			var offset := OFFSETS[i] if side == Unit.Side.PLAYER1 else -OFFSETS[i]
			battle.add_unit(kinds[i], side, hq + offset)
	return battle
