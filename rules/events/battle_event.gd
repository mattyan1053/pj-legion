@abstract
class_name BattleEvent
extends RefCounted
## 起きたことの共通の親。Battle.apply() の結果（ActionResult.events）に順に並ぶ。
##
## イベントは起きた時点の値を持つ（駒は番号で指す）。あとで状態が変わっても、イベントの中身は変わらない。
