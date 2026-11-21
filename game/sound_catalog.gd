extends RefCounted
## 鳴らす音の表（名前 -> 素材のファイルと、鳴らし方）。ノードに依存しない。
##
## 鳴らすのは sound.gd。場面ごとの BGM は scene_flow.gd の表（"music"）が、ここの曲の名前で決める。
## 対戦の曲は、盤の見た目ごと（LOOK_MUSIC）。ストーリーの話は、話のファイルで選び直せる（docs/sound.md）。
## **音を 1 つ足すのは、素材を assets/audio/ に置き（README.md と LICENSE を書く）、ここに 1 行足すだけ。**
## 鳴らす側は名前で頼む（sound.gd の play）。表に無い名前・ファイルの無い名前は、黙って何もしない
## （画面の側（game/）のコードが名前で鳴らす音が表にあることは、tests/game/test_sound.gd が確かめる）。

## 曲（BGM と決着の曲）。
## - path: 素材。loop: 終わったら頭へ戻るか（場面の曲）。偽なら 1 回だけ鳴らして止まる（決着の曲）。
## - volume_db: 曲ごとの大きさの釣り合い（設定の音量の前に掛ける）。
## - 大きさは、曲の平均の大きさ（EBU R128 の積分ラウドネス）を測ってそろえた。対戦の曲は -21.5 LUFS、会話の曲は -20 LUFS ほどに
##   なるように（volume_db = ねらい - 測った値）。耳では確かめていない。
## - メニューと会話は落ち着いた曲（RandomMind の中世の連作）、対戦は戦いの曲（オーケストラ。assets/audio/oga-battle/）。
##   対戦の曲を差し替えるときは、path を替えるだけ（次点の曲は assets/audio/oga-battle/README.md）。
const StageLook := preload("res://game/stage_look.gd")
const MUSIC := {
	&"menu": {"path": "res://assets/audio/randommind/medieval_exploration.ogg", "loop": true, "volume_db": -8.0},
	## 対戦（草原。弦と金管の勇ましい戦いの曲）。盤の見た目が分からないときの対戦の曲も、これ。
	&"battle": {"path": "res://assets/audio/oga-battle/battle_theme_a_loop.ogg", "loop": true, "volume_db": -11.0},
	## 対戦（石の遺跡。重く暗い 3 拍子の戦いの曲）。
	&"battle_ruins": {"path": "res://assets/audio/oga-battle/great_labyrinth.ogg", "loop": true, "volume_db": -10.0},
	## 対戦（結晶の森。打楽器の刻みが続く、異国風の戦いの曲）。
	&"battle_crystal": {"path": "res://assets/audio/oga-battle/sigil.ogg", "loop": true, "volume_db": -4.0},
	## 守り切る戦い（弦の速い刻みと金管。時間に追われる曲）。話のファイルの music で選ぶ。
	&"battle_tense": {"path": "res://assets/audio/oga-battle/determined_pursuit_loop.ogg", "loop": true, "volume_db": -8.5},
	## 中ボスを倒す戦い（巨大な魔物に挑む曲）。
	&"battle_boss": {"path": "res://assets/audio/oga-battle/the_fire_dragon_loop.ogg", "loop": true, "volume_db": -8.0},
	## 敵を全滅させる戦い（攻め込む行進の曲。4 分あり、途中で形が変わる）。
	&"battle_rout": {"path": "res://assets/audio/oga-battle/qazijamjam.ogg", "loop": true, "volume_db": -8.5},
	## 魔物（骸骨の軍）との戦い（不気味な行進の曲）。
	&"battle_undead": {"path": "res://assets/audio/oga-battle/the_march_of_devils_dome.ogg", "loop": true, "volume_db": -10.0},
	## 終盤（どちらかの将の HP が半分を切った）。対戦の途中で、この曲へフェードで替わる（CLIMAX_MUSIC）。
	&"battle_climax": {"path": "res://assets/audio/oga-battle/epic_boss_battle_loop.ogg", "loop": true, "volume_db": -14.5},
	## ストーリーの会話（話のファイルの before_music・after_music で選ぶ。docs/sound.md）。前の会話は、ふつうは対戦の曲を小さく（TALK_BATTLE_DB）。
	## 軽い会話（酒場の曲。演習の始まりなど）。
	&"talk": {"path": "res://assets/audio/randommind/medieval_the_old_tower_inn_loop.ogg", "loop": true, "volume_db": -2.5},
	## 勝って明るい会話（祝いの曲）。
	&"talk_bright": {"path": "res://assets/audio/randommind/medieval_rejoicing_loop.ogg", "loop": true, "volume_db": -8.5},
	## 落ち着いた会話（ピアノと弦。戦いのあとの一息、和解）。あとの会話の既定。
	&"talk_calm": {"path": "res://assets/audio/oga-talk/waiting_ii.ogg", "loop": true, "volume_db": -1.0},
	## 悲しい会話（弔い）。
	&"talk_sad": {"path": "res://assets/audio/randommind/fantasy_lament_for_a_warriors_soul.ogg", "loop": true, "volume_db": -3.5},
	## 不穏な会話（対決、明かされる真実）。
	&"talk_dark": {"path": "res://assets/audio/oga-talk/the_confrontation.ogg", "loop": true, "volume_db": -2.0},
	## 戦いのあとの重い会話（倒れた兵を思う）。
	&"talk_aftermath": {"path": "res://assets/audio/oga-talk/aftermath.ogg", "loop": true, "volume_db": -3.5},
	&"victory": {"path": "res://assets/audio/randommind/medieval_victory_theme.ogg", "loop": false, "volume_db": -6.0},
	&"defeat": {"path": "res://assets/audio/randommind/medieval_defeat_theme.ogg", "loop": false, "volume_db": -6.0},
}

## 終盤の曲。対戦の途中で、どちらかの将の HP が CLIMAX_KING_HP（最大 HP に対する割合）以下になったら（倒れたときも）、
## この曲へ替わる（battle_screen.gd）。戻らない。新しい対戦を始めると、その対戦の曲に戻る。
const CLIMAX_MUSIC := &"battle_climax"
const CLIMAX_KING_HP := 0.5

## 会話の場面で対戦の曲（名前が battle で始まる曲）を鳴らすときに、表の大きさから下げる dB（台詞を読む間は控えめに）。
## 前の会話から対戦へ同じ曲で入ると、鳴らし直さずに、表の大きさへフェードで戻る。
const TALK_BATTLE_DB := -6.0
## 前の会話・あとの会話の曲を話のファイルが書かないときの、あとの会話の曲。前の会話は、その話の対戦の曲。
const AFTER_TALK_MUSIC := &"talk_calm"
## 決着の曲（ファンファーレ）が鳴り終えたあとに続ける曲（ループ）。ストーリーの話は、その話のあとの会話の曲（そのまま会話へつながる）。
const AFTER_RESULT_MUSIC := &"talk_calm"

## 勝ったときの調子（話のファイルの victory_mood）。明るい: ファンファーレを鳴らしてから、静かな曲へ。
## 静か: ファンファーレを鳴らさず、対戦の曲を消して静かな曲へ（敵討ちのあと、弔いの話など）。
const MOOD_BRIGHT := &"bright"
const MOOD_QUIET := &"quiet"
const MOODS: Array[StringName] = [MOOD_BRIGHT, MOOD_QUIET]

## 効果音。
## - path: 素材。volume_db: 音ごとの大きさ（操作の音は控えめに、BGM の下に置く）。
## - weak: 真なら、同じフレームにほかの操作の音が鳴ったら鳴らさない（ボタンの音。押した結果の音のほうを聞かせる）。
const EFFECTS := {
	## ボタンを押した（どのボタンも。ほかの音が鳴るなら譲る）。
	&"ui_click": {"path": "res://assets/audio/kenney/click_001.ogg", "volume_db": -10.0, "weak": true},
	## 決めた（駒を選ぶ、対戦を始める、確かめて進む）。
	&"ui_confirm": {"path": "res://assets/audio/rubberduck/item_gem_01.ogg", "volume_db": -12.0},
	## 1 つ戻した（右クリック・Esc で戻す、確かめをやめる）。
	&"ui_back": {"path": "res://assets/audio/kenney/cloth1.ogg", "volume_db": -6.0},
	## 押せないものを押した（灰色のボタン）。
	&"ui_denied": {"path": "res://assets/audio/kenney/dropLeather.ogg", "volume_db": -10.0},
	## メニュー・ログを開いた、閉じた。
	&"menu_open": {"path": "res://assets/audio/kenney/bookOpen.ogg", "volume_db": -2.0},
	&"menu_close": {"path": "res://assets/audio/kenney/bookClose.ogg", "volume_db": -12.0},

	## ---- 対戦の中の出来事（docs/sound.md の「対戦の音」）----
	## 大きさは、素材の大きさ（鳴っている間の平均）から、BGM より少し下にそろえた（耳では確かめていない）。
	## gap（秒）: その間は同じ音を鳴らし直さない（続けて起きる回復・被弾などが連打に聞こえないように）。

	## 攻撃が当たった（当たり方ごと。battle_effects.gd の STYLE_SOUNDS）。
	&"hit_slam": {"path": "res://assets/audio/untamedpixels/impact_punch_heavy_002.ogg", "volume_db": -17.0, "gap": 0.08},
	&"hit_slash": {"path": "res://assets/audio/rubberduck/blade_01.ogg", "volume_db": -10.0, "gap": 0.08},
	&"hit_shot": {"path": "res://assets/audio/rubberduck/bfh1_wood_hit_01.ogg", "volume_db": -15.0, "gap": 0.08},
	&"hit_magic": {"path": "res://assets/audio/rubberduck/spell_01.ogg", "volume_db": -13.0, "gap": 0.08},
	&"hit_plain": {"path": "res://assets/audio/rubberduck/bfh1_hit_08.ogg", "volume_db": -12.0, "gap": 0.08},
	## 当たった音に重ねる: クリティカル（金属の高い響き）、状態が防いだ（金属を叩く短い音）。
	&"critical": {"path": "res://assets/audio/janschupke/sword-clash-04.ogg", "volume_db": -15.0, "gap": 0.1},
	&"blocked": {"path": "res://assets/audio/rubberduck/bfh1_metal_hit_01.ogg", "volume_db": -9.0, "gap": 0.1},
	## 駒が倒れた（鎧が崩れ落ちる）。
	&"defeated": {"path": "res://assets/audio/rubberduck/bfh1_metal_falling_02.ogg", "volume_db": -12.0, "gap": 0.25},
	## 樽が爆発した。
	&"explosion": {"path": "res://assets/audio/untamedpixels/fire_spell_impact_4.ogg", "volume_db": -18.0, "gap": 0.3},
	## 中ボスが現れた（吠える）。
	&"boss_roar": {"path": "res://assets/audio/rubberduck/creature_roar_02.ogg", "volume_db": -13.0, "gap": 0.5},

	## 回復（回復役・泉・再生・聖域）。
	&"heal": {"path": "res://assets/audio/untamedpixels/healing_spell_impact_10.ogg", "volume_db": -16.0, "gap": 0.6},
	## スキル（系統ごと。battle_effects.gd の SKILL_SOUNDS）。形が対象に届いた瞬間に鳴る。
	&"skill_fire": {"path": "res://assets/audio/untamedpixels/fire_spell_impact_4.ogg", "volume_db": -18.0, "gap": 0.3},
	&"skill_guard": {"path": "res://assets/audio/untamedpixels/earth_spell_impact_4.ogg", "volume_db": -18.0, "gap": 0.3},
	&"skill_holy": {"path": "res://assets/audio/untamedpixels/healing_spell_impact_11.ogg", "volume_db": -19.0, "gap": 0.3},
	&"skill_wind": {"path": "res://assets/audio/untamedpixels/wind_spell_impact_5.ogg", "volume_db": -17.0, "gap": 0.3},
	&"skill_focus": {"path": "res://assets/audio/untamedpixels/ice_spell_impact_5.ogg", "volume_db": -12.0, "gap": 0.3},
	## 必殺技を使った（画面が光る瞬間に 1 回だけ。効果の掛かった駒ごとには鳴らさない）。
	&"ult": {"path": "res://assets/audio/untamedpixels/lightning_spell_impact_3.ogg", "volume_db": -11.0, "gap": 0.5},
	## 必殺技のゲージがいっぱいになった。
	&"ult_ready": {"path": "res://assets/audio/rubberduck/bell_02.ogg", "volume_db": -14.0, "gap": 0.5},

	## ポータルで転移した。
	&"portal": {"path": "res://assets/audio/rubberduck/spell_02.ogg", "volume_db": -14.0, "gap": 0.3},
	## 聖遺物を手に入れた。
	&"relic": {"path": "res://assets/audio/rubberduck/bell_03.ogg", "volume_db": -18.0, "gap": 1.0},
	## 拠点の占拠が進んだ。
	&"capture": {"path": "res://assets/audio/rubberduck/gong_02.ogg", "volume_db": -12.0, "gap": 0.5},
	## レベルが上がった（竪琴）、進化した（光が満ちる音）。
	&"level_up": {"path": "res://assets/audio/spring-spring/health_restore.ogg", "volume_db": -12.0, "gap": 0.6},
	&"evolved": {"path": "res://assets/audio/untamedpixels/healing_spell_impact_3.ogg", "volume_db": -14.0, "gap": 0.6},
	## 陣営の番が始まった（中立の番は鳴らさない）。
	&"phase": {"path": "res://assets/audio/rubberduck/gong_01.ogg", "volume_db": -14.0},
}


## 盤の見た目（stage_look.gd の THEMES の鍵）-> 対戦の曲。表に無い見た目は battle。
const LOOK_MUSIC := {
	StageLook.GRASSLAND: &"battle",
	StageLook.STONE_WALLS: &"battle_ruins",
	StageLook.CRYSTAL_FOREST: &"battle_crystal",
	StageLook.QUARRY: &"battle_crystal",
	StageLook.SEAM: &"battle_crystal",
	StageLook.BARROW: &"battle_ruins",
	StageLook.PASS: &"battle",
	StageLook.RIDGE: &"battle_ruins",
	StageLook.DEEP_FOREST: &"battle_crystal",
	StageLook.DRILL_YARD: &"battle_ruins",
}


## 盤の見た目 look_name の対戦の曲。
static func battle_music(look_name: StringName) -> StringName:
	return LOOK_MUSIC.get(look_name, &"battle")


## 対戦の初めの将（両陣営の UnitKind.Id.KING）の番号。終盤の判定（climax_reached）に渡す。
static func kings_of(battle: Battle) -> Array[int]:
	var ids: Array[int] = []
	for unit in battle.units:
		if unit.kind == UnitKind.Id.KING and unit.side != Unit.Side.NEUTRAL:
			ids.append(unit.id)
	return ids


## 終盤に入ったか: 初めにいた将（king_ids）のどれかの HP が、最大 HP の CLIMAX_KING_HP 以下になった（倒れたときも）。
## どちらの将かは問わない（曲が形勢を告げないように）。決着がついたあとは偽（決着の曲を消さない）。
static func climax_reached(battle: Battle, king_ids: Array[int]) -> bool:
	if battle.is_over():
		return false
	for id in king_ids:
		var king := battle.unit_by_id(id)
		if king == null or king.hp <= king.max_hp() * CLIMAX_KING_HP:
			return true
	return false


## 対戦の曲か（名前が battle で始まる）。会話の場面では、小さくして鳴らす（TALK_BATTLE_DB）。
static func is_battle_music(track: StringName) -> bool:
	return String(track).begins_with("battle")


## 会話の場面で曲 track を鳴らすときの、表の大きさからの差（dB）。
static func talk_offset_db(track: StringName) -> float:
	return TALK_BATTLE_DB if is_battle_music(track) else 0.0


static func has_music(track: StringName) -> bool:
	return MUSIC.has(track)


static func has_effect(name: StringName) -> bool:
	return EFFECTS.has(name)


## 表の曲・効果音のうち、素材のファイルが無いもの（res:// の道）。検査用。
static func missing_files() -> Array[String]:
	var missing: Array[String] = []
	for table: Dictionary in [MUSIC, EFFECTS]:
		for entry: Dictionary in table.values():
			if not ResourceLoader.exists(entry["path"]):
				missing.append(entry["path"])
	return missing
