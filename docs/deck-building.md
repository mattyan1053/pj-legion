# 編成の検査

コード: `rules/deck.gd`（`Deck.problems()`、`Deck.is_valid()`、`Deck.Problem`、`Deck.MAX_UNITS`）、
`rules/deck_entry.gd`（`DeckEntry.equip`）、`rules/equipment.gd`（`Equipment.MAX_PER_UNIT`）。
テスト: `tests/rules/test_deck_building.gd`。

編成そのもの（軍、ロスター、装備、コスト、予算）は `docs/player-loadout.md`。
編成画面（操作、表示、対戦相手ごとの画面の流れ）は、ここには無い。

## 対戦に出せる編成

編成（`Deck`）は、次を全部満たすときだけ対戦に出せる。

| 満たさないときの理由（`Deck.Problem`） | 条件 |
| --- | --- |
| `NO_UNITS` | 雇った駒（将を除く）が 1 体以上いる |
| `TOO_MANY_UNITS` | 雇った駒が 6 体（`Deck.MAX_UNITS`）以下 |
| `OVER_BUDGET` | 合計コストが、選んだ軍の予算以下（ちょうどは通る） |
| `TOO_MUCH_EQUIPMENT` | どの駒も、装備が 3 個（`Equipment.MAX_PER_UNIT`）以下 |
| `NOT_IN_ROSTER` | どの駒も、選んだ軍のロスターの種類 |

- `Deck.problems()` が、満たしていない理由を全部返す。空なら出せる。
  並びは上の表の順で、同じ理由は 1 回だけ（当てはまる駒が何体いても）。
- `Deck.is_valid()` は、理由が 1 つも無いかどうか。
- 検査は編成を変えない。駒や装備を足し引きしたあとは、呼び直す。
- 理由に付ける文言は、画面の側が持つ。
- 軍を選んでいない編成（`Army.NONE`）は、ロスターも予算も無いので、必ず通らない。

## 編成の途中

編成の途中は、対戦に出せない形にもなる。途中で断るものと、検査で分かるものを分ける。

- **その場で断るもの**（編成に入らない）: ロスターに無い種類と、上限を超える駒（`Deck.add` が `null`）、
  上限を超える装備（`DeckEntry.equip` が `false`）。
- **検査で分かるもの**（編成には入る）: 予算を超えている、駒が 0 体。
  予算を超える駒や装備も足せて、外せば（`Deck.remove`、`DeckEntry.unequip`）戻る。

`TOO_MANY_UNITS`、`TOO_MUCH_EQUIPMENT`、`NOT_IN_ROSTER` は、`add` / `equip` を通していれば起きない。
`entries` や `equipment` を直に組み立てた編成（保存したものの読み込み、自動生成）のために検査に入れている。

## 検査と、軍を盤に置くこと

`Deployment.deploy` は検査をしない。**対戦を始める側が、編成を渡す前に `is_valid()` を確かめる。**
人が組んだ編成も、自動で作った編成（CPU の相手）も、同じ検査を通ったものだけを対戦に出す。
