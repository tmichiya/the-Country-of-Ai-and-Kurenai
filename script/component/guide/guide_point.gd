class_name GuidePoint
extends Marker2D
## ガイドの目的地 1 か所。ステージに置き、Guide の destinations に順番に登録する。

## 到達とみなす範囲。空ならガイドの既定の円を使う。
## 同じ場所にイベント用の Area があるなら、その Shape を共有すると「着いた」と「イベント発火」がそろう。
@export var reach_shape: Shape2D
## 三角を目的地からどれだけずらして描くか（像や人物の頭上に出したいとき）。
@export var marker_offset: Vector2 = Vector2(0, -16)
