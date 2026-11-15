extends RefCounted
## 中立のフェーズに起きたことを、見せ方の単位（場面）に分ける。ノードにもルールにも依存しない（イベントを読むだけ）。
##
## 中立の駒は 1 体ずつ「動く → 攻撃する」。それをそのまま順に、1 体ずつカメラで追うと、何も起きなかった駒のために
## カメラが盤の端から端へ飛び続けて、目で追えない。そこで、起きたことを駒ごとの場面に分け、2 種類に見分ける:
## - 静かな場面: 動いただけ、湧いただけ（UnitMovedEvent、UnitWarpedEvent、UnitSpawnedEvent だけ）。
##   カメラを動かさず、続いている静かな場面をまとめて同時に流す。
## - 見せる場面: それ以外（攻撃した、煙幕に阻まれた、倒した…）。カメラを寄せて、1 体ずつ、追える速さで見せる。
## 起きた順は変えない（静かな場面をまとめるのは、間に見せる場面をはさまずに続いているものだけ）。

## 場面 1 つ。actor_id は主役の駒（動いた・攻撃した・湧いた駒）、events は起きたこと（起きた順）、quiet は静かな場面か。
class Beat:
	var actor_id := 0
	var events: Array[BattleEvent] = []
	var quiet := true


## events（中立の PhaseStartedEvent の次から、次のフェーズの手前まで）を、場面に分ける。
static func beats(events: Array[BattleEvent]) -> Array[Beat]:
	var result: Array[Beat] = []
	var current: Beat = null
	for event in events:
		var actor := _actor_of(event)
		# 主役が替わったら（または湧いたら）、新しい場面。主役のいないイベント（倒れた、経験値…）は、いまの場面に続ける。
		if current == null or (actor != 0 and (actor != current.actor_id or event is UnitSpawnedEvent)):
			current = Beat.new()
			current.actor_id = actor
			result.append(current)
		current.events.append(event)
		if not (event is UnitMovedEvent or event is UnitWarpedEvent or event is UnitSpawnedEvent):
			current.quiet = false
	return result


## 場面を、見せる順のまとまりに分ける。続いている静かな場面は 1 つのまとまり（同時に流す）、見せる場面は 1 つずつ。
static func groups(all: Array[Beat]) -> Array[Array]:
	var result: Array[Array] = []
	for beat in all:
		if beat.quiet and not result.is_empty() and (result.back()[0] as Beat).quiet:
			result.back().append(beat)
		else:
			result.append([beat])
	return result


## イベントの主役の駒（動いた・転移した・湧いた・攻撃した駒）。主役のいないイベントなら 0。
static func _actor_of(event: BattleEvent) -> int:
	if event is UnitMovedEvent or event is UnitWarpedEvent or event is UnitSpawnedEvent:
		return event.get(&"unit_id")
	if event is AttackDamagedEvent or event is SmokeBlockedEvent:
		return event.get(&"attacker_id")
	return 0
