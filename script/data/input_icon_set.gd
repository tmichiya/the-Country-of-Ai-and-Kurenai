class_name InputIconSet
extends Resource
## 入力アクション名 → 操作アイコン の対応表。入力デバイスの種類ごとに 1 つずつ持つ。
## 絵を差し替えるときは、この .tres の中身を入れ替えるだけでよい（使う側のシーンは触らない）。

@export var mouse_keyboard: Dictionary[StringName, Texture2D] = {}
@export var gamepad: Dictionary[StringName, Texture2D] = {}


func get_icon(action: StringName, use_gamepad: bool) -> Texture2D:
	var table := gamepad if use_gamepad else mouse_keyboard
	return table.get(action, null)
