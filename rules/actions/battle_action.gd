@abstract
class_name BattleAction
extends RefCounted
## 行動の共通の親。Battle.apply() に渡す。
##
## 行動は駒を番号（Unit.id）で指し、駒そのものは持たない。同じ行動を、複製した Battle にも渡せる。


## いまの状態で受け付けられるか。状態は変えない。
@abstract func is_valid(battle: Battle) -> bool


## 状態を進め、起きたことを返す。is_valid() が真のときだけ呼ばれる。
@abstract func execute(battle: Battle) -> Array[BattleEvent]
