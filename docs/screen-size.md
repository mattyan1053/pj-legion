# 画面の大きさ

コード: `game/screen_size.gd`（論理の大きさの計算と、検査で大きさを決める入口）、`project.godot` の `display/window`。
テスト: `tests/game/test_screen_size.gd`。

## いまの仕様

- 画面の部品は、基準の大きさ 1280×720（`display/window/size/viewport_*`）の上に並べ、窓の大きさに合わせて拡大・縮小する（`display/window/stretch/mode` が `canvas_items`）。
- 縦横比の扱いは `display/window/stretch/aspect`。`keep` では、16:9 でない窓に黒い帯が出る。

## 窓と全画面

コード: `game/window_mode.gd`（アプリ `game/app.gd` が 1 つ持つ）。テスト: `tests/game/test_window_mode.gd`。

- 初めは 1280×720 の窓で開く。窓の端をドラッグして、大きさを自由に変えられる（`display/window/size/resizable` は既定のオン）。
- 窓は 960×540 より小さくできない（`window_mode.gd` の `MIN_WINDOW_SIZE`）。これより小さいと、文字が読めないほど小さくなる。
- 設定の「全画面」（区分「画面」。`docs/system-menu.md`）で、全画面（`Window.MODE_FULLSCREEN`。枠の無い全画面）と窓を切り替える。次に起動しても残る。
- **Alt+Enter** でも切り替えられる。どの場面でも、システムメニューを開いていても効く（場面より先に受ける）。切り替えたら、すぐに設定を取っておく。
- 検査とスクリーンショットの道具は、窓に触らない（決めた大きさで回すため）。

## 大きさを変えて確かめる

- スクリーンショット: `tools/screenshots.sh godot <出力> <場面> --size=<幅>x<高さ>`（`docs/screenshots.md`）。
- 自動の対戦: `godot --headless --path . -- --autoplay --size <幅>x<高さ>`。
  画面の無い検査では窓が開かないので、その大きさの窓のときの論理の大きさ（`ScreenSize.logical_size`）を直に決めて回す。
  `--size` が無ければ 1280×720。
