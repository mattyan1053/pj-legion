extends "res://game/battle_log/log_fights.gd"
## 対戦のログ（docs/battle-log.md）。起きたこと（BattleEvent）を順に食わせて、読める行の列にする。ノードに依存しない。
##
## 対戦の状態は読まない（数え始めに盤上の駒と盤面を控えることだけ。BattleStats と同じ）。駒の名前・陣営・いるマスは、
## 控えた駒をイベントで追いかけて知る（倒れた駒も、名前は残る）。
## どのイベントをどう読むかは readers() の表に載せる。載っていない種類があると、テストが落ちる。
##
## ここは、読み方の表（readers()）と、食わせる入口。読み方は game/battle_log/ に分けてあり、次の順に継ぐ:
## log_base.gd（行・控えた駒・行の足し方）→ log_moves.gd（動きと盤）→ log_fights.gd（戦い）→ ここ。


## battle の数え始め（ふつうは始まる前）。盤上の駒と盤面を控え、いまのフェーズの見出しを置く。
## names は見出しに出す陣営の名前（プレイヤー1、プレイヤー2 の順。CPU なら、そう書いたもの）。空なら既定の名前。
func _init(battle: Battle, names: Array[String] = []) -> void:
	if names.size() >= 2:
		side_names = [names[0], names[1], Names.side(Unit.Side.NEUTRAL)]
	_board = battle.board
	for unit in battle.units:
		var known := Known.new(unit.kind, unit.side, unit.cell)
		known.evolution = unit.evolution
		_units[unit.id] = known
	_start_phase(battle.turn, battle.phase)
	# 始めからゲージがたまっている陣営（対戦モードの先手、ゲージの手前から始める話）は、そう書いておく。
	if battle.turn == 1 and battle.phase == Unit.Side.PLAYER1:
		for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
			if Ults.of(battle, side) != null and Ults.gauge(battle, side) > 0:
				_line(Text.t("battle.log.start_gauge", {"side": Names.side_word(side), "percent": Ults.percent(battle, side)}), side)


## イベントの種類（スクリプト）-> 読むメソッドの名前。rules/events/ のイベントは、すべてここに載せる。
## 行にしない（ほかの行に書いたことと重なる、細かすぎる）種類は &"_skip" にする。なぜ省くかは docs/battle-log.md。
static func readers() -> Dictionary:
	return {
		PhaseStartedEvent: &"_read_phase_started",
		UnitMovedEvent: &"_read_moved",
		UnitWarpedEvent: &"_read_warped",
		MoveUndoneEvent: &"_read_undone",
		UnitActedEvent: &"_read_acted",
		AttackDamagedEvent: &"_read_attack_damaged",
		SmokeBlockedEvent: &"_read_smoke_blocked",
		SkillUsedEvent: &"_read_skill_used",
		SkillDamagedEvent: &"_read_effect_damaged",
		ExplosionDamagedEvent: &"_read_effect_damaged",
		BarrelExplodedEvent: &"_read_barrel_exploded",
		BarricadeDamagedEvent: &"_read_barricade_damaged",
		BarricadePlacedEvent: &"_read_field_effect_placed",
		AreaEffectPlacedEvent: &"_read_field_effect_placed",
		KnotPlacedEvent: &"_read_field_effect_placed",
		RallyEvent: &"_read_rally",
		BurstEvent: &"_read_burst",
		FieldEffectRemovedEvent: &"_read_field_effect_removed",
		UnitTeleportedEvent: &"_read_teleported",
		UnitsSwappedEvent: &"_read_swapped",
		UnitReactivatedEvent: &"_read_reactivated",
		HealerHealedEvent: &"_read_healer_healed",
		SpringHealedEvent: &"_read_healed",
		RegenerationHealedEvent: &"_read_healed",
		SupplyHealedEvent: &"_read_healed",
		SanctuaryHealedEvent: &"_read_healed",
		CardHealedEvent: &"_read_healed",
		CardPlayedEvent: &"_read_card_played",
		CardDrawnEvent: &"_read_card_drawn",
		UnitPushedEvent: &"_read_pushed",
		StatusAppliedEvent: &"_read_status_applied",
		TraitTriggeredEvent: &"_read_trait",
		UltUsedEvent: &"_read_ult_used",
		UltReadyEvent: &"_read_ult_ready",
		UnitDefeatedEvent: &"_read_defeated",
		MidBossDefeatedEvent: &"_read_mid_boss_defeated",
		RelicGainedEvent: &"_read_relic_gained",
		UnitSpawnedEvent: &"_read_spawned",
		LevelUpEvent: &"_read_level_up",
		UnitEvolvedEvent: &"_read_evolved",
		CaptureProgressEvent: &"_read_capture",
		StrongholdProgressEvent: &"_read_stronghold",
		GameWonEvent: &"_read_won",
		GameDrawnEvent: &"_read_drawn",
		# 行にしないもの。
		ExperienceGainedEvent: &"_skip",  # 毎回の経験値は細かすぎる。レベルアップの行で足りる
		EvolutionOfferedEvent: &"_skip",  # 選んだ進化先の行（UnitEvolvedEvent）で足りる
		FieldEffectTickedEvent: &"_skip",  # 残りのターン数が減るだけ。消えたときに書く
		SkillReadyEvent: &"_skip",  # 毎フェーズの細かいこと。駒の情報で分かる
		StatusRemovedEvent: &"_skip",  # 防いだ・外れたことは、ダメージの行と移動の行で分かる
	}


func feed_all(events: Array[BattleEvent]) -> void:
	for event in events:
		feed(event)


## 起きたことを 1 つ読む。Battle.apply() が返した順に食わせる
## （画面は再生した順に食わせる。中立の動くだけの駒をまとめて同時に流しても、駒ごとの順は保たれる）。
func feed(event: BattleEvent) -> void:
	var kind: Script = event.get_script()
	var method: StringName = readers().get(kind, &"")
	if method == &"":
		push_error("ログに読み方の無いイベント: %s" % kind.resource_path)
		return
	call(method, event)
	if not event is UnitSpawnedEvent:
		_spawn_kind = -1
	_undoing = event is MoveUndoneEvent or (_undoing and (event is CaptureProgressEvent or event is StatusAppliedEvent))


## 前に呼んでから書き換えた、いちばん前の行の番号を返し、覚えを空にする（画面は、そこから先を作り直す）。
## 書き換えていなければ entries.size()。
func take_changes() -> int:
	var from := _changed_from
	_changed_from = entries.size()
	return from
