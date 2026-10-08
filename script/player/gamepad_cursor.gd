extends Node2D

func _process(delta: float) -> void:
	if InputDevice.current_device == InputDevice.Device.GAMEPAD:
		visible = true
		rotation = InputDevice.get_move_direction().angle()
	else:
		visible = false