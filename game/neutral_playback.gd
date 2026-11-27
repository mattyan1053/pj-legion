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


## events[at] が中立の PhaseStartedEvent のとき、そのフェーズに盤に中立の駒がいたか（いれば、番の知らせを出す）。
## 中立の駒のいない番は、番の知らせも上の帯の「中立の番」も出さずに飛ばす（毎回、一瞬だけ中立の番が挟まるのは落ち着かない）。
## neutral_ids_at_start は、そのフェーズの始めに盤にいた中立の駒の番号（再生の盤 replay_board.gd から。対戦の進んだあとの状態は読まない）。
## いなくても、そのフェーズの中で湧けば出す（途中で現れたマップでは、現れた番から出す）。
static func phase_has_neutrals(events: Array[BattleEvent], at: int, neutral_ids_at_start: Array[int]) -> bool:
	if not neutral_ids_at_start.is_empty():
		return true
	for i in range(at + 1, events.size()):
		var event := events[i]
		if event is PhaseStartedEvent or event is GameWonEvent or event is GameDrawnEvent:
			return false
		var spawned := event as UnitSpawnedEvent
		if spawned != null and spawned.side == Unit.Side.NEUTRAL:
			return true
	return false


# ---- 出来事の表（tests/game/test_event_readers.gd が見張る。docs/battle.md の「出来事を 1 つ足すとき」） ----


## 中立の再生の場面分けが名前で読む出来事（このファイルの `is` / `as` に出てくるもの。親を読めば子も読む）。
static func read_events() -> Array[Script]:
	return [
		UnitMovedEvent,
		UnitWarpedEvent,
		UnitSpawnedEvent,
		AttackDamagedEvent,
		SmokeBlockedEvent,
		PhaseStartedEvent,
		GameWonEvent,
		GameDrawnEvent,
	]


## 中立の再生の場面分けが読まないと決めた出来事（新しい出来事を足したら、読むか、ここに理由と足す）。
static func skipped_events() -> Array[Script]:
	return [
		# 主役のいない出来事。いまの場面に続け、見せる場面にする（攻撃のあとに起きるもの）
		StatusAppliedEvent,
		StatusRemovedEvent,
		UnitDefeatedEvent,
		RallyEvent,
		BurstEvent,
		ExplosionDamagedEvent,
		KnotPlacedEvent,
		ExperienceGainedEvent,
		LevelUpEvent,
		EvolutionOfferedEvent,
		MidBossDefeatedEvent,
		RelicGainedEvent,
		TraitTriggeredEvent,
		# 同じ扱い（主役がいない）。中立のフェーズには、ふつう起きないもの
		MoveUndoneEvent,
		UnitActedEvent,
		UnitTeleportedEvent,
		UnitsSwappedEvent,
		UnitReactivatedEvent,
		UnitEvolvedEvent,
		SkillUsedEvent,
		SkillDamagedEvent,
		SkillReadyEvent,
		UltUsedEvent,
		UltReadyEvent,
		BarrelExplodedEvent,
		BarricadeDamagedEvent,
		BarricadePlacedEvent,
		AreaEffectPlacedEvent,
		FieldEffectRemovedEvent,
		FieldEffectTickedEvent,
		HealerHealedEvent,
		SanctuaryHealedEvent,
		SpringHealedEvent,
		RegenerationHealedEvent,
		SupplyHealedEvent,
		CardHealedEvent,
		CardDrawnEvent,
		CardPlayedEvent,
		UnitPushedEvent,
		CaptureProgressEvent,
		StrongholdProgressEvent,
	]
