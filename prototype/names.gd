extends RefCounted
## 画面に出す名前の表（陣営、軍、役割、能力、特性、盤の上の効果）。ノードに依存しない。
## 対戦の画面（battle_hud.gd）、ログ（battle_log.gd）、編成の画面の文（deck_text.gd）、対戦の設定（match_setup_panel.gd）、
## 道具（tools/cpu_matches.gd）が、ここを引く。列挙の値を足したら、ここに 1 行足す（足し忘れは tests/prototype/test_names.gd が落ちる）。

## 陣営の名前（見出し、番の知らせ、決着、本陣のマス）。
const SIDE_NAMES := {
	Unit.Side.PLAYER1: "プレイヤー1（青）",
	Unit.Side.PLAYER2: "プレイヤー2（赤）",
	Unit.Side.NEUTRAL: "中立",
}
## 陣営の短い名前（ログの駒の名前の前、上の帯の陣営ごとの欄）。
const SIDE_WORDS := {
	Unit.Side.PLAYER1: "青",
	Unit.Side.PLAYER2: "赤",
	Unit.Side.NEUTRAL: "中立",
}
## 軍の名前。軍を持たない駒（将、中立）は「軍なし」。
const ARMY_NAMES := {
	UnitKind.Army.NONE: "軍なし",
	UnitKind.Army.MILITARY: "MILITARY",
	UnitKind.Army.FANTASY: "FANTASY",
}
## 役割の名前（役割を持たない駒（将、中立）は載せない）。
const ROLE_NAMES := {
	UnitKind.Role.VANGUARD: "前衛",
	UnitKind.Role.REARGUARD: "後衛",
	UnitKind.Role.RAIDER: "奇襲",
	UnitKind.Role.HEALER: "回復",
}
## 能力の名前（この順に並べて出す）。
const STAT_NAMES := {
	Unit.Stat.MAX_HP: "最大 HP",
	Unit.Stat.POWER: "攻撃",
	Unit.Stat.MOVE_RANGE: "移動",
	Unit.Stat.ATTACK_RANGE: "射程",
}
## 進化先の特性の説明。
const TRAIT_TEXTS := {
	Evolution.Trait.EXERTS_ZOC: "周り 8 マスに支配領域を作る（敵はそこで止まる）",
	Evolution.Trait.IGNORES_ZOC: "敵の支配領域で止まらない",
	Evolution.Trait.FOREST_WALK: "森を平地と同じ移動力で歩く",
	Evolution.Trait.REGENERATION: "自分の番の始めに %d 回復" % Evolution.REGENERATION_HEAL,
}
## 盤の上の効果の名前。
const FIELD_EFFECT_NAMES := {
	FieldEffect.Type.BARRICADE: "盾",
	FieldEffect.Type.SMOKE: "煙幕",
	FieldEffect.Type.SANCTUARY: "聖域",
}
