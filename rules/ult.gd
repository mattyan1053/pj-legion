@abstract
class_name Ult
extends RefCounted
## 軍ごとの必殺技 1 つの定義（docs/tactical-ult.md）。
##
## 実際の必殺技は rules/ults/ の子のクラス。状態は持たない（ゲージと使った回数は対戦が持つ。Battle.ult_gauge）。
## 共通の決まり（ためる、誰が・いつ使えるか、使ったらゲージが空になる）は Ults が持ち、子のクラスは次だけを書く。
##
## - どの軍の必殺技か（army）、名前と説明
## - 効果（apply）。起きたことを返す
##
## 必殺技は駒の行動ではなく、プレイヤーの行動（UseUltAction）。対象は選ばない。駒の行動を使わない。

enum Id {
	ALL_OUT_ASSAULT,  ## 総員突撃（MILITARY）
	MANA_ERUPTION,  ## 魔力解放（FANTASY）
}


@abstract func id() -> Id


## この必殺技を持つ軍。1 つの軍は、必殺技を 1 つだけ持つ。
@abstract func army() -> UnitKind.Army


@abstract func display_name() -> String


## 画面に出す 1 行の説明。
@abstract func summary() -> String


## side の軍に効果を起こし、起きたことを返す。
## ゲージを空にするのと、使った回数を数えるのは Ults がするので、ここでは触らない。
@abstract func apply(battle: Battle, side: Unit.Side) -> Array[BattleEvent]
