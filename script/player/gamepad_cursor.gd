extends Node2D

func _process(delta: float) -> void:
	if InputDevice.current_device == InputDevice.Device.GAMEPAD:
		visible = true
		# 斬撃と同じ方向を指す。立ち止まっている間は向いている方向（右に戻らない）
		var owner_player := get_parent()
		if owner_player and owner_player.has_method("get_facing_direction"):
			rotation = owner_player.get_facing_direction().angle()
		else:
			rotation = InputDevice.get_move_direction().angle()
	else:
		visible = false