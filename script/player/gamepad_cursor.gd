extends Node2D

## 会話中か。会話中はゲームパッドでもカーソルを出さない。
var _is_chatting: bool = false

func _ready() -> void:
	Dialogue.chat_active_changed.connect(_on_chat_active_changed)
	# 会話の途中で生成された場合に備えて、今の状態から始める
	_is_chatting = Dialogue.is_displaying

func _on_chat_active_changed(active: bool) -> void:
	_is_chatting = active
	if active:
		visible = false

func _process(delta: float) -> void:
	if InputDevice.current_device == InputDevice.Device.GAMEPAD and not _is_chatting:
		visible = true
		# 斬撃と同じ方向を指す。立ち止まっている間は向いている方向（右に戻らない）
		var owner_player := get_parent()
		if owner_player and owner_player.has_method("get_facing_direction"):
			rotation = owner_player.get_facing_direction().angle()
		else:
			rotation = InputDevice.get_move_direction().angle()
	else:
		visible = false
