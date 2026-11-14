# 対戦の状態と行動の受け付け

コード: `rules/battle.gd`（`apply`、`can_apply`、`options`、`clone`、`rng`）、`rules/action_result.gd`、
`rules/unit_options.gd`、`rules/actions/battle_action.gd`、`rules/events/battle_event.gd`、`rules/state_copy.gd`。
テスト: `tests/rules/test_battle.gd`、`tests/rules/test_unit_options.gd`。

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
  | `UnitHealedEvent` | `HealerHealedEvent`（回復役の回復） | `healer_id` |
  | | `SpringHealedEvent`（回復の泉） | `cell` |

  HP の変化だけを追う側（戦闘予測、CPU）は、親として読めば足りる。
- `apply` は `BattleAction` しか受け取らない。イベントや駒を渡すと、スクリプトの読み込みの時点でエラーになる。

## apply の結果

`Battle.apply(行動)` は `ActionResult` を返す。

- `accepted` が偽: 行動は断られた。状態は何も変わらず、`events` は空。
- `accepted` が真: 行動を受け付けた。`events` に起きたことが起きた順に並ぶ。
  受け付けたが何も起きなかった行動では、`events` が空になる（断られた行動とは `accepted` で見分ける）。
- 決着したあとは、どの行動も断る（`docs/win-conditions.md`）。将が倒れたか・本陣の占拠が途切れたかは `Battle.settle` が見る。
  `apply` が行動のあとに呼び、中立のフェーズ（`docs/neutral-minion.md`）は駒 1 体の行動ごとに呼ぶ。
- `Battle.can_apply(行動)` は、状態を変えずに、いま受け付けるかだけを答える。

## 選べること

`Battle.options(駒の番号)` は、その駒がいま選べることを `UnitOptions` にまとめて返す。状態は変えない。
画面（選べるマスを塗る）と CPU（選べる行動を並べる）の両方が使う。

| 値 | 中身 |
| --- | --- |
| `move_cells` | 通常の移動で届くマス -> 使う移動力。いまのマス（動かない移動）も含む |
| `cruise_cells` | 巡航でだけ届くマス -> 使う移動力。`move_cells` とは重ならない |
| `attack_target_ids` | いまの位置から攻撃できる駒の番号 |
| `barrel_cells` | いまの位置から攻撃できる起爆樽のマス |
| `heal_target_ids` | いまの位置から回復できる味方の番号 |
| `can_wait`、`can_undo` | 待機できるか、移動を取り消せるか |

- 載っているものは、`can_apply` が受け付ける行動と一致する（載っていない行動は断られる）。
  もう動いた駒では移動のマスが空、巡航で動いた駒では攻撃と回復の相手が空になる。
- 行動できない駒（相手の番、行動済み、ほかの駒が行動の途中、決着のあと、いない駒）では、すべて空（`is_empty()` が真）。
- 相手の並びは、盤面の上の行から、左の列から。
- `actions()` は、選べる行動を `apply` に渡せる形で並べる（移動、巡航、攻撃、樽の攻撃、回復、待機、取り消しの順。毎回同じ並び）。
  通常の移動で届くマスへの巡航は、受け付けはするが並べない（攻撃を諦めるだけで得が無い）。
- 駒は番号で指すので、複製（下）にもそのまま使える。作った時点の写しなので、状態が進んだら作り直す。
- フェーズを終える行動（`EndPhaseAction`）は駒のものではないので、ここには載らない。

## 複製

`Battle.clone()` は対戦の状態を丸ごと複製する。戦闘予測と CPU の先読みは、複製に `apply` して結果を見る。

- 複製と元は、どちらに `apply` しても、もう片方は変わらない。盤面（環境オブジェクトを含む）、駒（位置・HP・行動の状態）、
  ターン、フェーズ、行動の途中の駒、本陣の占拠の数、勝者と引き分け、駒の番号の採番、乱数のすべてが別になる。
- 駒の番号は元と同じ。元に向けて作った行動を、そのまま複製に渡せる。
- 複製のあとに置いた駒は、元に置いた場合と同じ番号になる。

## 乱数

- 確率で決まるルールは、`Battle.rng` だけを使う。シードは `Battle.new(盤面, シード)` で渡す（省略すると 0）。
- 同じ盤面・同じシード・同じ行動の列からは、いつも同じ結果になる。
- 複製の乱数は、元がこの先に引くはずだった値を同じ順に引く。複製から引いても、元の乱数は進まない。
- 盤面の生成（`BoardGenerator`）は対戦の前に済むので、自分のシードで引く（`docs/game-board.md`）。
