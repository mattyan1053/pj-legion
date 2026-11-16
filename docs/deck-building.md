# 編成の検査

コード: `rules/deck.gd`（`Deck.problems()`、`Deck.is_valid()`、`Deck.Problem`、`Deck.MAX_UNITS`）、`rules/deck_rules.gd`（編成の決まり）、
`rules/deck_entry.gd`（`DeckEntry.equip`）、`rules/equipment.gd`（`Equipment.MAX_PER_UNIT`）。
テスト: `tests/rules/test_deck_building.gd`、`tests/rules/test_deck_rules.gd`。

編成そのもの（軍、ロスター、装備、コスト、予算）は `docs/player-loadout.md`。
編成画面（操作、表示、対戦相手ごとの画面の流れ）は、ここには無い。

## 編成の決まり

「どの軍を選べ、それぞれの軍でどの駒を雇えるか」「予算はいくつか」「何体まで雇えるか」は、編成の決まり（`DeckRules`）が持つ。
編成（`Deck`）は組むときに決まりを受け取り、検査も編成の画面も、その決まりで調べる。決め打ちの値を読まない。

| 決まり（`DeckRules.id`） | 使うところ | 中身 |
| --- | --- | --- |
| `versus`（`DeckRules.versus()`） | 対戦。全員が同じ決まりで組む | 軍ごとのロスター 4 種と予算（`docs/player-loadout.md` の表）、6 体まで |
| `story`（`game/story.gd` の `deck_rules()`） | ストーリー。人だけが使う | ストーリーの軍のロスターは、いま雇える駒（進み具合で増える。`docs/story.md` の「駒の解放」）。予算と数の上限は対戦と同じ |

- 決まりを渡さずに組んだ編成（`Deck.new(軍)`、`CpuDeck.build(軍)`）は、対戦の決まりで組む。
- 取っておく部隊は、どの決まりで組んだか（`id`）を持つ。読み込むときに `DeckRules.by_id` で引き直す（知らない名前なら `null`）。
- 決まりは組んだら変えない。
- ストーリーの決まりは進み具合で変わるので、`rules/` ではなく画面の側（`game/story.gd`）が作る。`DeckRules.by_id` は知らない（取っておいた部隊の読み方は `docs/deck-screen.md`）。
  対戦用とストーリー用の部隊は、決まりの名前で分ける。

## 対戦に出せる編成

編成（`Deck`）は、次を全部満たすときだけ対戦に出せる。

| 満たさないときの理由（`Deck.Problem`） | 条件 |
| --- | --- |
| `NO_UNITS` | 雇った駒（将を除く）が 1 体以上いる |
| `TOO_MANY_UNITS` | 雇った駒が、決まりの上限以下（対戦の決まりでは 6 体。`Deck.MAX_UNITS`） |
| `OVER_BUDGET` | 合計コストが、決まりの、選んだ軍の予算以下（ちょうどは通る） |
| `TOO_MUCH_EQUIPMENT` | どの駒も、装備が 3 個（`Equipment.MAX_PER_UNIT`）以下 |
| `NOT_IN_ROSTER` | どの駒も、決まりの、選んだ軍のロスターの種類 |

- `Deck.problems()` が、満たしていない理由を全部返す。空なら出せる。
  並びは上の表の順で、同じ理由は 1 回だけ（当てはまる駒が何体いても）。
- `Deck.is_valid()` は、理由が 1 つも無いかどうか。
- 検査は編成を変えない。駒や装備を足し引きしたあとは、呼び直す。
- 理由に付ける文言は、画面の側が持つ。
- 軍を選んでいない編成（`Army.NONE`）と、決まりに無い軍の編成は、ロスターも予算も無いので、必ず通らない。

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
