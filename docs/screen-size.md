# 画面の大きさ

コード: `game/screen_size.gd`（論理の大きさの計算と、検査で大きさを決める入口）、`project.godot` の `display/window`。
テスト: `tests/game/test_screen_size.gd`。

## いまの仕様

- 画面の部品は、基準の大きさ 1280×720（`display/window/size/viewport_*`）の上に並べ、窓の大きさに合わせて拡大・縮小する（`display/window/stretch/mode` が `canvas_items`）。
- 縦横比の扱いは `display/window/stretch/aspect`。`keep` では、16:9 でない窓に黒い帯が出る。

## 大きさを変えて確かめる

- スクリーンショット: `tools/screenshots.sh godot <出力> <場面> --size=<幅>x<高さ>`（`docs/screenshots.md`）。
- 自動の対戦: `godot --headless --path . -- --autoplay --size <幅>x<高さ>`。
  画面の無い検査では窓が開かないので、その大きさの窓のときの論理の大きさ（`ScreenSize.logical_size`）を直に決めて回す。
  `--size` が無ければ 1280×720。
