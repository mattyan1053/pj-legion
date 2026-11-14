@abstract
class_name Skill
extends RefCounted
## 駒の種類ごとのスキル 1 つの定義（docs/active-skills.md）。
##
## 実際のスキルは rules/skills/ の子のクラス。状態は持たない（クールダウンは駒が持つ。Unit.skill_cooldown）。
## 共通の決まり（誰が・いつ使えるか、クールダウン、行動の終わり）は Skills が持ち、子のクラスは次だけを書く。
##
## - 誰のスキルか（kind）、名前と説明、クールダウン
## - いまの位置から選べる対象のマス（target_cells）と、対象を選んだときに効果が及ぶマス（affected_cells）
## - 効果（apply）。起きたことを返す
##
## スキルを足すときは、Id に 1 つ足し、子のクラスを書き、Skills.ALL に並べる（docs/active-skills.md の「スキルを足すとき」）。

enum Id {
	TACTICAL_BARRICADE,  ## 戦術バリケード（シールドトルーパー）
	SAINT_PLACE,  ## セイントプレイス（プリースト）
}


@abstract func id() -> Id


## このスキルを持つ駒の種類。1 種類の駒は、スキルを 1 つだけ持つ。
@abstract func kind() -> UnitKind.Id


@abstract func display_name() -> String


## 画面に出す 1 行の説明。
@abstract func summary() -> String


## 使ったときに駒に付くクールダウン。持ち主のフェーズの始めに 1 減り、0 で使える。
## N なら、使ったターンの N ターン後にまた使える。
@abstract func cooldown() -> int


## 共通の条件（クールダウン、巡航）のほかに、このスキルだけの条件があれば、ここで見る。
func is_ready(_battle: Battle, _unit: Unit) -> bool:
	return true


## unit がいまの位置から選べる対象のマス（並びは問わない。Skills が上の行から、左の列からに並べる）。
## 自分に使うスキルは自分のマス、駒を選ぶスキルはその駒のマスを返す。
@abstract func target_cells(battle: Battle, unit: Unit) -> Array[Vector2i]


## target を選んだときに、効果が及ぶマス（画面が塗る。戦闘予測の範囲）。
func affected_cells(_battle: Battle, _unit: Unit, target: Vector2i) -> Array[Vector2i]:
	return [target]


## 効果を起こし、起きたことを返す。target は target_cells のどれか（Skills が確かめてから呼ぶ）。
## クールダウンと行動の終わりは Skills が面倒を見るので、ここでは触らない。
@abstract func apply(battle: Battle, unit: Unit, target: Vector2i) -> Array[BattleEvent]
