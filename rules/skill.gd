@abstract
class_name Skill
extends RefCounted
## 駒の種類ごとのスキル 1 つの定義（docs/active-skills.md）。
##
## 実際のスキルは rules/skills/ の子のクラス。状態は持たない（クールダウンは駒が持つ。Unit.skill_cooldown）。
## 共通の決まり（誰が・いつ使えるか、クールダウン、行動の終わり）は Skills が持ち、子のクラスは次だけを書く。
##
## - 誰のスキルか（kind）、説明に差し込む値（summary_args。名前と説明の文は game/text/names.csv）、クールダウン
## - いまの位置から選べる対象のマス（target_cells）と、対象を選んだときに効果が及ぶマス（affected_cells）
## - 効果（apply）。起きたことを返す
##
## スキルを足すときは、Id に 1 つ足し、子のクラスを書き、Skills.ALL に並べる（docs/active-skills.md の「スキルを足すとき」）。

enum Id {
	TACTICAL_BARRICADE,  ## 戦術バリケード（シールドトルーパー）
	SAINT_PLACE,  ## セイントプレイス（プリースト）
	SMOKE_GRENADE,  ## スモークグレネード（コマンドー）
	FIREBALL,  ## ファイアボール（ソーサラー）
	DIVINE_SHIELD,  ## ディバインシールド（パラディン）
	PRECISION_AIM,  ## 精密照準（スナイパー）
	SHADOW_STEP,  ## シャドウステップ（スペルブレード）
	ADRENALINE_SHOT,  ## アドレナリン注射（衛生兵）
	BONE_RAISE,  ## 骨起こし（骸骨術師。魔物）
	WAR_DRUM,  ## 骨太鼓（骸骨鼓手。魔物）
}


@abstract func id() -> Id


## このスキルを持つ駒の種類。1 種類の駒は、スキルを 1 つだけ持つ。
@abstract func kind() -> UnitKind.Id


## 名前と 1 行の説明は、画面の文の表（game/text/names.csv）が持つ（鍵は id の名前の小文字。game/names.gd）。
## 説明の文に差し込む値（調整値）。無ければ空。
func summary_args() -> Dictionary:
	return {}


## 使ったときに駒に付くクールダウン。持ち主のフェーズの始めに 1 減り、0 で使える。
## N なら、使ったターンの N ターン後にまた使える。
@abstract func cooldown() -> int


## 使うと行動を終えるか（ふつうは終える）。
## 偽なら、使ったあとも行動の途中のままで、続けて攻撃・待機ができる。もう動けず、移動の取り消しもできない（Skills.use）。
func ends_action() -> bool:
	return true


## 1 体の駒が、対戦中に使える回数の上限。0 なら上限なし。使った回数は駒が持つ（Unit.skill_uses）。
func max_uses() -> int:
	return 0


## 共通の条件（クールダウン、巡航、回数）のほかに、このスキルだけの条件があれば、ここで見る。
func is_ready(_battle: Battle, _unit: Unit) -> bool:
	return true


## unit がいまの位置から選べる対象のマス（並びは問わない。Skills が上の行から、左の列からに並べる）。
## 自分に使うスキルは自分のマス、駒を選ぶスキルはその駒のマスを返す。
@abstract func target_cells(battle: Battle, unit: Unit) -> Array[Vector2i]


## target を選んだときに、効果が及ぶマス（画面が塗る。戦闘予測の範囲）。
func affected_cells(_battle: Battle, _unit: Unit, target: Vector2i) -> Array[Vector2i]:
	return [target]


## 脅威範囲（docs/threat-range.md）が読む: unit がいまの位置からこのスキルを使ったら、ダメージが届きうるマスと、その量。
## Vector2i -> int。煙幕にも防がれないものとして数える。ダメージの無いスキルでは空（既定）。
## 状態は変えない。unit は盤にいない写し（動いた先に置いた駒）のこともある。
func threat_damage(_battle: Battle, _unit: Unit) -> Dictionary[Vector2i, int]:
	return {}


## 脅威範囲が読む: unit がいまの位置からこのスキルを使ったあと、同じ行動の中で攻撃できるマス（移った先）。
## 行動を終えるスキルと、駒が移らないスキルでは空（既定）。状態は変えない。threat_damage と同じく、unit は写しのこともある。
func threat_origins(_battle: Battle, _unit: Unit) -> Array[Vector2i]:
	return []


## 効果を起こし、起きたことを返す。target は target_cells のどれか（Skills が確かめてから呼ぶ）。
## クールダウン、使った回数、行動の終わり（終えないスキルなら、行動の続き）は Skills が面倒を見るので、ここでは触らない。
@abstract func apply(battle: Battle, unit: Unit, target: Vector2i) -> Array[BattleEvent]
