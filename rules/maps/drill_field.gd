extends RefCounted
## 手で作ったマップ「練兵場」（docs/hand-map.md）。9 x 13 の小さな盤。ストーリーのチュートリアルの話（game/episodes/）に使う。
##
## 教えることだけが起きる盤: 中立の駒（結晶泉・中ボス）は置かず、障害物と森を少しと、回復の泉を両軍の側に 1 つずつ。
## 本陣は上下の中央。盤の中心で点対称。文字の意味は HandMap の定数。

const TITLE := "練兵場"
const ROWS: Array[String] = [
	"....2....",
	".........",
	"..F...F..",
	".......S.",
	"...#.#...",
	".........",
	"....F....",
	".........",
	"...#.#...",
	".S.......",
	"..F...F..",
	".........",
	"....1....",
]


static func map() -> HandMap:
	return HandMap.new(PackedStringArray(ROWS))
