extends Node2D

func _process(delta: float) -> void:
	if InputDevice.current_device == InputDevice.Device.GAMEPAD:
		visible = true
		rotation = InputDevice.get_aim_angle(self)
	else:
		visible = false