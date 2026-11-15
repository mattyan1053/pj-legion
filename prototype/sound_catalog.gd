extends RefCounted
## 鳴らす音の表（名前 -> 素材のファイルと、鳴らし方）。ノードに依存しない。
##
## 鳴らすのは sound.gd。場面ごとの BGM は scene_flow.gd の表（"music"）が、ここの曲の名前で決める。
## **音を 1 つ足すのは、素材を assets/audio/ に置き（README.md と LICENSE を書く）、ここに 1 行足すだけ。**
## 鳴らす側は名前で頼む（sound.gd の play）。表に無い名前・ファイルの無い名前は、黙って何もしない
## （鳴らす場所を先に書いておき、素材は後で足してよい）。

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
