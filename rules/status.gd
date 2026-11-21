class_name Status
extends RefCounted
## 駒に一定の間だけ付く状態の種類と、種類ごとの決まり（docs/unit-statuses.md）。
##
## どの駒に何が付いているかは駒が持つ（Unit.statuses: 種類 -> 残りのターン数）。
## 付ける・外す・期限を進めるのは Statuses。ここは種類ごとの定義だけで、状態を持たない。
##
## 状態が駒にすること（どれも Statuses が、種類の定義を読んで面倒を見る）:
## - 能力値の補正（bonus）。付いている間、駒の「一時的な補正」の層（Unit.temporary_bonus）に足される
## - 受けるダメージを 0 にする（blocks_damage）。1 回で外れる。ダメージの解決（Hit.resolve）が見る
## - 攻撃を確定クリティカルにする（critical_percent）。攻撃 1 回で外れる。Combat.hit が見る
## - 動くと外れる（breaks_on_move）

enum Type {
	BARRIER,  ## バリア。次に受けるダメージを 1 回だけ 0 にする（ディバインシールド）
	AIM,  ## 照準。射程が伸び、次の攻撃が確定クリティカルになる。動くと外れる（精密照準）
	FATIGUE,  ## 反動。攻撃力が下がる（アドレナリン注射を受けた駒）
	ASSAULT,  ## 突撃。移動力と攻撃力が上がる（必殺技の総員突撃）
	MARCH,  ## 強行軍。移動力が上がる（作戦の強行軍）
}

## クリティカルでない攻撃の倍率（%）。
const NORMAL_PERCENT := 100


## 付いている間の能力値の補正（Unit.Stat -> 足す量）。無ければ空。
static func bonus(type: Type) -> Dictionary:
	if type == Type.AIM:
		return {Unit.Stat.ATTACK_RANGE: PrecisionAimSkill.RANGE_BONUS}
	if type == Type.FATIGUE:
		return {Unit.Stat.POWER: -AdrenalineShotSkill.POWER_PENALTY}
	if type == Type.ASSAULT:
		return {Unit.Stat.MOVE_RANGE: AllOutAssaultUlt.MOVE_BONUS, Unit.Stat.POWER: AllOutAssaultUlt.POWER_BONUS}
	if type == Type.MARCH:
		return {Unit.Stat.MOVE_RANGE: Tactics.MARCH_MOVE}
	return {}


## 受けるダメージを 0 にして、外れるか。
static func blocks_damage(type: Type) -> bool:
	return type == Type.BARRIER


## 付いている駒の攻撃（駒・盾への攻撃）の攻撃力に掛ける倍率（%）。攻撃（樽への攻撃も含む）を 1 回すると外れる。
## 攻撃に関わらない状態は NORMAL_PERCENT。
static func critical_percent(type: Type) -> int:
	return PrecisionAimSkill.CRITICAL_PERCENT if type == Type.AIM else NORMAL_PERCENT


## 攻撃を 1 回すると外れるか。
static func ends_on_attack(type: Type) -> bool:
	return type == Type.AIM


## 駒がほかのマスへ動くと外れるか。
static func breaks_on_move(type: Type) -> bool:
	return type == Type.AIM
