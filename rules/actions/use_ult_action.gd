class_name UseUltAction
extends BattleAction
## いまのフェーズのプレイヤーが、軍の必殺技を使う（docs/tactical-ult.md）。
##
## 駒の行動ではない（駒を指さない。対象も選ばない）。使っても、どの駒の行動も使わない。
## 使えるのは、ゲージがいっぱいのとき。使うとゲージは 0 に戻る。

func is_valid(battle: Battle) -> bool:
	return Ults.can_use(battle)


func execute(battle: Battle) -> Array[BattleEvent]:
	return Ults.use(battle)
