# pj-legion（プロジェクト・レギオン）

1vs1 のタクティクスボードゲーム。2D で作っていた [pj-region](https://github.com/mattyan1053/pj-region)（非公開）を、
Godot で**ゲーム性はそのまま、見た目を俯瞰 3D に**作り直す趣味プロジェクト。

## 動かし方

1. [Godot 4.7 の通常版](https://godotengine.org/download/)（.NET 版ではないほう）を入れる
2. このリポジトリを clone し、Godot の「インポート」で `project.godot` を開く
3. F5 で実行する

いまは見た目の試作（`prototype/`）だけが入っている。ルールはまだ無い。

| 操作 | 内容 |
| --- | --- |
| WASD / 矢印 | カメラの移動 |
| Q / E | 90 度回転 |
| R | 見下ろす角度の切り替え（3 段階） |
| ホイール | 拡大・縮小 |
| 左クリック | 駒の選択 / 選択中の駒を移動 |
| 右クリック | 選択の解除 |

## 検査

```bash
tools/check.sh /path/to/godot
```

画面なしでプロジェクトを取り込み、メインシーンを少し動かして、スクリプトのエラーが無いことを確かめる。
CI（`.github/workflows/ci.yml`）も同じスクリプトを回す。

作業の決まりごとは [`CLAUDE.md`](./CLAUDE.md)、文書の置き方は [`docs/README.md`](./docs/README.md)。
