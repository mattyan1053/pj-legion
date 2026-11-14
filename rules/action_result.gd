class_name ActionResult
extends RefCounted
## Battle.apply() の結果。
##
## accepted が偽なら、行動は断られ、状態は何も変わっていない（events は空）。
## accepted が真なら、行動は受け付けられ、events に起きたことが順に並ぶ。
## 受け付けたが何も起きなかった行動は、accepted が真で events が空になる。

var accepted: bool
var events: Array[BattleEvent]


func _init(was_accepted: bool, happened: Array[BattleEvent] = []) -> void:
	accepted = was_accepted
	events = happened


static func rejected() -> ActionResult:
	return ActionResult.new(false)
