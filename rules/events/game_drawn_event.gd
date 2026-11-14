class_name GameDrawnEvent
extends BattleEvent
## 決着した。勝者はいない（引き分け）。

enum Reason {
	BOTH_KINGS_DEFEATED,  ## 両方の将が同時に倒れた
}

var reason: Reason


func _init(why: Reason) -> void:
	reason = why
