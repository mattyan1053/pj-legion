class_name Terrain
extends RefCounted
## 地形の種類と、種類ごとの性質。
##
## 森の被ダメージ軽減は戦闘の側で決める（ここには置かない）。

enum Type {
	NORMAL,  ## 平地
	OBSTACLE,  ## 障害物。入れないが、射程は通す
	FOREST,  ## 森。入るのに移動力を多く使う
	FONT,  ## エネルギー結晶泉。中立の駒が湧く
}


static func is_walkable(type: Type) -> bool:
	return type != Type.OBSTACLE


## 入るのに使う移動力。入れない地形でも 1 を返すので、先に is_walkable で確かめる。
static func move_cost(type: Type) -> int:
	return 2 if type == Type.FOREST else 1


## 射程（攻撃の届く線）を遮るか。いまはどの地形も遮らない（壁越しに撃てる）。
static func blocks_range(_type: Type) -> bool:
	return false
