extends RefCounted
## 鳴らす音の表（名前 -> 素材のファイルと、鳴らし方）。ノードに依存しない。
##
## 鳴らすのは sound.gd。場面ごとの BGM は scene_flow.gd の表（"music"）が、ここの曲の名前で決める。
## **音を 1 つ足すのは、素材を assets/audio/ に置き（README.md と LICENSE を書く）、ここに 1 行足すだけ。**
## 鳴らす側は名前で頼む（sound.gd の play）。表に無い名前・ファイルの無い名前は、黙って何もしない
## （画面の側（game/）のコードが名前で鳴らす音が表にあることは、tests/game/test_sound.gd が確かめる）。

## 曲（BGM と決着の曲）。
## - path: 素材。loop: 終わったら頭へ戻るか（場面の曲）。偽なら 1 回だけ鳴らして止まる（決着の曲）。
## - volume_db: 曲ごとの大きさの釣り合い（設定の音量の前に掛ける）。
const MUSIC := {
	&"menu": {"path": "res://assets/audio/randommind/medieval_exploration.ogg", "loop": true, "volume_db": -8.0},
	&"battle": {"path": "res://assets/audio/randommind/medieval_minstrel_dance_loop.ogg", "loop": true, "volume_db": -9.0},
	&"victory": {"path": "res://assets/audio/randommind/medieval_victory_theme.ogg", "loop": false, "volume_db": -6.0},
	&"defeat": {"path": "res://assets/audio/randommind/medieval_defeat_theme.ogg", "loop": false, "volume_db": -6.0},
}

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
