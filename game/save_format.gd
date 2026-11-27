extends RefCounted
## セーブの中身の版と、知らない欄の扱い（docs/save-slots.md の「版と、知らない欄」）。ノードに依存しない。
##
## 新しい exe で書いたセーブを、古い exe で開いて保存しても、新しい欄を落とさない・版を下げないための決まり:
## - 欄を足したら、そのまとまりの FORMAT_VERSION を上げる。古い exe は、版が自分より新しい中身の知らない欄を、読んだまま残して
##   書き戻し（unknown・with_unknown）、版は読んだ版のまま書く（written_version）。新しい exe が、自分の欄をそのまま読み直せる。
## - 版が同じか古い中身の知らない欄は、やめた欄（前の版にあった欄）なので捨てる。
## - いまある欄の意味や形は変えない。変えたいときは、別の名前の欄を足す（古い exe は前の欄を読み、新しい欄を残す）。
##   どうしても変えるなら、読み替え（そのまとまりの _migrate）を足して版を上げ、スロットの版（save_slots.gd の FORMAT_VERSION）も上げる
##   （古い exe は、版の新しいスロットを開かない）。
## - 古い版のセーブは、新しい exe が版の番号を見て読み替える（形で見分けない）。


## data（版 read_version。いまの版は current）のうち、known に無い名前の欄（写し）。版が新しくなければ空（やめた欄は捨てる）。
static func unknown(data: Dictionary, known: Array, read_version: int, current: int) -> Dictionary:
	var found := {}
	if read_version <= current:
		return found
	for key: Variant in data:
		if not known.has(key):
			found[key] = data[key] if typeof(data[key]) not in [TYPE_DICTIONARY, TYPE_ARRAY] else data[key].duplicate(true)
	return found


## 書く中身 data に、読んだときの知らない欄 kept を戻したもの（data にある名前は data のまま）。
static func with_unknown(data: Dictionary, kept: Dictionary) -> Dictionary:
	var written := data
	for key: Variant in kept:
		if not written.has(key):
			written[key] = kept[key] if typeof(kept[key]) not in [TYPE_DICTIONARY, TYPE_ARRAY] else kept[key].duplicate(true)
	return written


## 書くときの版: 読んだ版がいまの版より新しければ、読んだ版のまま（新しい exe の欄を残しているので）。
static func written_version(read_version: int, current: int) -> int:
	return maxi(read_version, current)
