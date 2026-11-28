# 対戦の状態と行動の受け付け

コード: `rules/battle.gd`（`apply`、`can_apply`、`options`、`clone`、`rng`）、`rules/action_result.gd`、`rules/mend.gd`（回復の道）、
`rules/unit_options.gd`、`rules/actions/battle_action.gd`、`rules/events/battle_event.gd`、`rules/state_copy.gd`。
テスト: `tests/rules/test_battle.gd`、`tests/rules/test_mend.gd`、`tests/rules/test_unit_options.gd`、`tests/game/test_event_readers.gd`（出来事を種類ごとに読む所の表）。

1 回の対戦の状態は `Battle` が持つ。状態を変えるのは `Battle.apply(行動)` だけ
（対戦の準備で駒を置く `add_unit` は除く）。

## 行動とイベント

- 行動はすべて `BattleAction` を継承する。いまの状態で受け付けられるかを `is_valid`、状態を進めて起きたことを返すのを
  `execute` に書く。行動は駒を番号で指す。
- 起きたことはすべて `BattleEvent` を継承する。起きた時点の値を持ち、駒は番号で指す。
  再生する側は、イベントの値だけで再生できる（対戦の状態を読み直さなくてよい）。
- **イベントは、当てはまる値だけを持つ。**「いない駒」を 0 番で表すことはしない。
  原因がいくつかある出来事は、共通の親（`UnitDamagedEvent`、`UnitHealedEvent`。どちらも駒・量・あとの HP・`cause` を持つ）と、
  原因ごとの子に分ける。原因に固有の値は子だけが持つので、当てはまらない値は読もうとした時点でエラーになる。

  | 親 | 子 | 子だけが持つ値 |
  | --- | --- | --- |
  | `UnitDamagedEvent` | `AttackDamagedEvent`（駒の攻撃） | `attacker_id` |
  | | `ExplosionDamagedEvent`（起爆樽の爆発） | `barrel_cell` |
  | | `SkillDamagedEvent`（ダメージのあるスキル） | `user_id`、`skill` |
  | `UnitHealedEvent` | `HealerHealedEvent`（回復役の回復） | `healer_id` |
  | | `SpringHealedEvent`（回復の泉） | `cell` |
  | | `RegenerationHealedEvent`（進化先の特性の再生） | - |
  | | `SanctuaryHealedEvent`（聖域） | `effect_id` |
  | | `SupplyHealedEvent`（軍略の補給線） | `medic_id` |
  | `FieldEffectPlacedEvent` | `BarricadePlacedEvent`（盾） | `durability` |
  | | `AreaEffectPlacedEvent`（煙幕・聖域） | `turns_left` |

  HP の変化だけを追う側（戦闘予測、CPU）は、親として読めば足りる。
- `apply` は `BattleAction` しか受け取らない。イベントや駒を渡すと、スクリプトの読み込みの時点でエラーになる。

### 出来事を 1 つ足すとき

`rules/events/` に新しい出来事（`BattleEvent` の子）を足したら、次の所を触る。**どれも、触り忘れるとテストか自動の対戦が落ちる。**

1. 出来事のスクリプト（`rules/events/`）と、それを返すルール。返す順を、その機能の文書に書く。
2. 再生: `game/battle_playback.gd` の `event_players()` に載せ、再生するメソッドを書く（`docs/battle-view.md`）。
   表に無いと `tests/game/test_event_playback.gd` が、自動の対戦で 1 度も再生されないと `game/autoplay.gd` が落ちる。
   1 度も起きない出来事なら、起きる場面を自動の対戦（`game/autoplay/`）に足す。
3. ログ: `game/battle_log.gd` の `readers()` に載せる。行にしないなら `_skip` に理由を添えて載せる（`docs/battle-log.md`）。
   表に無いと `tests/game/test_battle_log.gd` が落ちる。
4. 種類ごとに読む 6 か所で、**読むか、読まないかを決める**。どこも、ファイルの終わりに「読む出来事」（`read_events`）と
   「読まないと決めた出来事」（`skipped_events`）の表がある。読むなら、コードに `is` / `as` で書き、読む表に足す。
   読まないなら、読まない表に理由と足す。どちらにも無いか、読む表がコードの `is` / `as` とずれると、`tests/game/test_event_readers.gd` が落ちる。
   親（`UnitDamagedEvent` など）を読んでいれば、子は読むほうに数える。
   台本の出来事（`game/cut_events/`。カットシーンの台本だけが出す。`docs/battle-view.md` の「盤のカットシーン」）を足すときは、再生の表と再生の盤の表だけ。
   - 戦績・MVP: `rules/battle_stats.gd`（`docs/battle-stats.md`）
   - 予測のまとめ: `rules/forecast.gd`（`docs/battle-forecast.md`）
   - CPU の手の価値: `rules/cpu/cpu_outcome_value.gd`（`docs/cpu-ai.md`）
   - 実測の道具: `tools/cpu_match.gd`（種類ごとの数は、読まなくても数える）
   - 中立の再生の場面分け: `game/neutral_playback.gd`（主役になる出来事か）
   - 再生の盤: `game/replay_board.gd`（盤の見え方（駒の位置・HP・状態など）を変える出来事か。`docs/battle-view.md` の「再生の盤」）
5. 予測のパネル・ログ・戦績で数字や文を出すなら、文の表（`game/text/`。`docs/text.md`）に足す。

### 回復を 1 つ足すとき

駒の HP を増やすものは、原因が何でも `rules/mend.gd`（`Mend`）を通す（ダメージの `rules/hit.gd` と対になる）。
`rules/` の中で駒の HP を書き換える所は、`tests/rules/test_mend.gd` の表（`HP_WRITERS`）にあるものだけ: 増やすのは `Mend.give`、減らすのは `Hit.apply`、
ほかは駒を作るときと、最大 HP が変わったときに合わせる所（`Unit.follow_max_hp`）。`hp = hp + n`・`hp -=`・`set("hp", …)` の形も、表に無い所なら落ちる。

- 戻す量は `Mend.amount(駒, 上限)`。最大 HP の実効値で止める。予測や CPU が「どれだけ戻るか」を聞くのもこれ（`Healing.amount` などは、ここを呼ぶ）。
  回復量を増やす・封じる効果は、ここに段として足す。
- 実際に戻すのは `Mend.give(駒, 上限, 出来事)`。出来事は原因ごとの子（`UnitHealedEvent` の子）を、原因の値（回復した駒など）だけ入れて作って渡す。
  駒・増えた量・あとの HP は `give` が書き込む。例: `Mend.give(unit, SUPPLY_HEAL, SupplyHealedEvent.new(medic.id))`。
- 新しい原因なら、`UnitHealedEvent` の子と `Cause` を足し、上の「出来事を 1 つ足すとき」をたどる。
  戦績で誰かの回復量に数えるかを、`tests/rules/test_battle_stats.gd` の `HEAL_COUNTED` に書く（書かないと落ちる）。
  数えるなら、`rules/battle_stats.gd` の `_count_heal` に、その子から回復した駒を読む行を足す（足し忘れると落ちる）。

## apply の結果

`Battle.apply(行動)` は `ActionResult` を返す。

- `accepted` が偽: 行動は断られた。状態は何も変わらず、`events` は空。
- `accepted` が真: 行動を受け付けた。`events` に起きたことが起きた順に並ぶ。
  受け付けたが何も起きなかった行動では、`events` が空になる（断られた行動とは `accepted` で見分ける）。
- 決着したあとは、どの行動も断る（`docs/win-conditions.md`）。将が倒れたか・本陣の占拠が途切れたかは `Battle.settle` が見る。
  `apply` が行動のあとに呼び、中立のフェーズ（`docs/neutral-minion.md`）は駒 1 体の行動ごとに呼ぶ。
- 進化先を選ぶのを待っている駒がいる間は、その駒の `EvolveAction` のほかは断る（`docs/branch-evolution.md`）。
- その行動で必殺技のゲージがいっぱいになったプレイヤーがいれば、`events` の最後に `UltReadyEvent` が付く（`docs/tactical-ult.md`）。
- `Battle.can_apply(行動)` は、状態を変えずに、いま受け付けるかだけを答える。

## 選べること

`Battle.options(駒の番号)` は、その駒がいま選べることを `UnitOptions` にまとめて返す。状態は変えない。
画面（選べるマスを塗る）と CPU（選べる行動を並べる）の両方が使う。

| 値 | 中身 |
| --- | --- |
| `move_cells` | 通常の移動で届くマス -> 使う移動力。いまのマス（動かない移動）も含む。ポータルの先へは広げない。転移のあと続けて動ける駒では、残りの移動力で届くマス（いまのマスは含まない） |
| `cruise_cells` | 巡航でだけ届くマス -> 使う移動力。`move_cells` とは重ならない。巡航で動いたあとの続きは、すべてこちら |
| `warp_exit` | いまのマスのポータルから転移できる先（`WarpAction`。`docs/map-objects.md`）。できなければ `Board.NO_CELL` |
| `attack_target_ids` | いまの位置から攻撃できる駒の番号 |
| `barrel_cells` | いまの位置から攻撃できる起爆樽のマス |
| `barricade_cells` | いまの位置から攻撃できる相手の盾のマス（`docs/field-effects.md`） |
| `heal_target_ids` | いまの位置から回復できる味方の番号 |
| `skill_cells` | いまの位置からスキルの対象に選べるマス（`docs/active-skills.md`）。スキルを使えない駒では空 |
| `evolutions` | 選べる進化先（A、B の順）。進化先を選ぶのを待っている駒だけ |
| `can_wait`、`can_undo` | 待機できるか、移動を取り消せるか（行動を終えないスキルを使ったあとは、取り消せない） |

- 載っているものは、`can_apply` が受け付ける行動と一致する（載っていない行動は断られる）。
  もう動いた駒では移動のマスが空（転移して続けて動ける駒を除く）、巡航で動いた駒では攻撃（駒・樽・盾）と回復の相手とスキルの対象が空になる。
- 行動できない駒（相手の番、行動済み、ほかの駒が行動の途中、決着のあと、いない駒）では、すべて空（`is_empty()` が真）。
- 進化先を選ぶのを待っている駒がいる間は、その駒の `evolutions` だけが載り、ほかはどの駒でも空になる。
- 相手の並びは、盤面の上の行から、左の列から。
- `actions()` は、選べる行動を `apply` に渡せる形で並べる（進化、移動、巡航、転移、攻撃、樽の攻撃、盾の攻撃、回復、スキル、待機、取り消しの順。毎回同じ並び）。
  通常の移動で届くマスへの巡航は、受け付けはするが並べない（攻撃を諦めるだけで得が無い）。
- 駒は番号で指すので、複製（下）にもそのまま使える。作った時点の写しなので、状態が進んだら作り直す。
- フェーズを終える行動（`EndPhaseAction`）と必殺技（`UseUltAction`）は駒のものではないので、ここには載らない。
  必殺技を使えるかは `Ults.can_use(対戦)`（`docs/tactical-ult.md`）。

## 複製

`Battle.clone()` は対戦の状態を丸ごと複製する。戦闘予測と CPU の先読みは、複製に `apply` して結果を見る。

- 複製と元は、どちらに `apply` しても、もう片方は変わらない。盤面（環境オブジェクトと盤の上の効果を含む）、駒（位置・HP・行動の状態・レベル・進化先・スキルのクールダウンと使った回数・付いている状態）、
  ターン、フェーズ、行動の途中の駒、本陣の占拠の数、プレイヤーの軍と必殺技のゲージ・使った回数、倒れた中ボスと持っている聖遺物、勝者と引き分け、駒の番号の採番、乱数のすべてが別になる。
- 駒の番号は元と同じ。元に向けて作った行動を、そのまま複製に渡せる。
- 複製のあとに置いた駒は、元に置いた場合と同じ番号になる。

## 乱数

- 確率で決まるルールは、`Battle.rng` だけを使う。シードは `Battle.new(盤面, シード)` で渡す（省略すると 0）。
- 同じ盤面・同じシード・同じ行動の列からは、いつも同じ結果になる。
- 複製の乱数は、元がこの先に引くはずだった値を同じ順に引く。複製から引いても、元の乱数は進まない。
- 盤面の生成（`BoardGenerator`）は対戦の前に済むので、自分のシードで引く（`docs/game-board.md`）。
