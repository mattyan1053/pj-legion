# テスト

## 置き場所

- ルール（ノードに依存しないクラス）は `rules/` に置く。
- テストは `tests/` に置く。ファイル名は `test_<機能の名前>.gd`。**置けば拾われる**（一覧に書き足す場所は無い）。
- `tests/` は書き出した exe には入らない。

## 書き方

```gdscript
extends "res://tests/test_case.gd"


func test_adjacent_cells_are_in_range() -> void:
	eq(Board.distance(Vector2i(0, 0), Vector2i(1, 0)), 1)
	check(Board.in_range(Vector2i(0, 0), Vector2i(1, 0), 1), "隣は射程 1 に入る")
```

- `test_` で始まるメソッドが 1 件のテスト。1 件ごとに新しいインスタンスで呼ばれる。
- 使えるのは `check(条件, 説明)` と `eq(実際, 期待, 説明)` の 2 つ。`eq` は型も比べる（`1` と `1.0` は別）。
- テストは同期で書く。`await` は使えない（ルールが演出を待たないので、要らない）。

## 回し方

```bash
tools/check.sh /path/to/godot                                    # 取り込み + テスト + メインシーン
godot --headless --path . --script res://tests/run.gd           # テストだけ（取り込み済みのとき）
```

## ルールに掛かっている制約

`tests/test_rules_are_node_free.gd` が、`rules/` の下のスクリプトについて次を確かめる。

- `Node` を継承していない
- `await` を使っていない
