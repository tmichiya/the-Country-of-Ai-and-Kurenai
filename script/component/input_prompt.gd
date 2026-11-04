@tool
class_name InputPrompt
extends Sprite2D
## action に対応する操作アイコンを、いま使っている入力デバイスに合わせて表示する。
## デバイスが切り替わった瞬間（InputDevice.device_changed）に絵が差し替わる。

const DEFAULT_ICON_SET: InputIconSet = preload("res://sprite/input/input_icon_set.tres")

@export var action: StringName = &"slash":
	set(value):
		action = value
		_refresh()

## 空なら DEFAULT_ICON_SET を使う。シーンごとに別の絵を使いたいときだけ指定する。
@export var icon_set: InputIconSet:
	set(value):
		icon_set = value
		_refresh()

## エディタ上でゲームパッド側の絵を確認するためのスイッチ（実行中は無視される）。
@export var preview_gamepad: bool = false:
	set(value):
		preview_gamepad = value
		_refresh()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_refresh()
	if Engine.is_editor_hint():
		return
	InputDevice.device_changed.connect(_on_device_changed)


func _on_device_changed(_device: InputDevice.Device) -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	var icons := icon_set if icon_set else DEFAULT_ICON_SET
	var use_gamepad := preview_gamepad if Engine.is_editor_hint() else InputDevice.is_gamepad()
	texture = icons.get_icon(action, use_gamepad)
