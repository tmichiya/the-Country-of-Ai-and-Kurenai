extends Node

enum Device { MOUSE_KEYBOARD, GAMEPAD }

signal device_changed(device: Device)

const STICK_ACTIVATE_THRESHOLD := 0.25
const AIM_DEADZONE := 0.2
const MOUSE_MOVE_THRESHOLD := 2.0

var current_device: Device = Device.MOUSE_KEYBOARD

var _last_stick_aim := Vector2.RIGHT

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_set_device(Device.GAMEPAD)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > STICK_ACTIVATE_THRESHOLD:
			_set_device(Device.GAMEPAD)
	elif event is InputEventMouseMotion:
		if event.relative.length() > MOUSE_MOVE_THRESHOLD:
			_set_device(Device.MOUSE_KEYBOARD)
	elif event is InputEventMouseButton or event is InputEventKey:
		_set_device(Device.MOUSE_KEYBOARD)


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	# 抜かれたらマウスへ戻す（挿されただけでは切り替えない＝触るまで待つ）
	if not connected and Input.get_connected_joypads().is_empty():
		_set_device(Device.MOUSE_KEYBOARD)


func _set_device(device: Device) -> void:
	if current_device == device:
		return
	current_device = device
	Input.mouse_mode = (Input.MOUSE_MODE_HIDDEN if device == Device.GAMEPAD
			else Input.MOUSE_MODE_VISIBLE)
	device_changed.emit(device)


func get_aim_direction(from: Node2D) -> Vector2:
	if current_device == Device.GAMEPAD:
		var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", AIM_DEADZONE)
		if not stick.is_zero_approx():
			_last_stick_aim = stick.normalized()
		return _last_stick_aim

	var to_mouse := from.get_global_mouse_position() - from.global_position
	if to_mouse.length() < 0.001:
		return _last_stick_aim  # カーソルが完全に重なった一瞬の保険
	return to_mouse.normalized()


func get_aim_angle(from: Node2D) -> float:
	return get_aim_direction(from).angle()


func is_gamepad() -> bool:
	return current_device == Device.GAMEPAD