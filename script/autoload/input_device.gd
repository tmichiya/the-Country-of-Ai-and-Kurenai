extends Node
## 「今どのデバイスで遊んでいるか」を管理し、エイム方向を提供する。
## エイムを取りたい側は get_aim_direction(self) だけを呼ぶ。

enum Device { MOUSE_KEYBOARD, GAMEPAD }

signal device_changed(device: Device)

## これ以上スティックを倒したら「パッドを触った」と見なす（ドリフト対策で高め）
const STICK_ACTIVATE_THRESHOLD := 0.25
## エイム入力として採用する最小の傾き（円形デッドゾーン）
const AIM_DEADZONE := 0.2
## マウスが動いたと見なす最小移動量（微振動での誤爆防止）
const MOUSE_MOVE_THRESHOLD := 2.0

var current_device: Device = Device.MOUSE_KEYBOARD

## 右スティックを離しても直前の向きを保持する（＝離した瞬間に暴発しない）
var _last_stick_aim := Vector2.RIGHT


func _ready() -> void:
	# ポーズ中もデバイス判定は動かす（ポーズメニューをパッドで操作した後、
	# 再開時に正しくゲームパッドモードのままであってほしい）
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


## from の位置から見たエイム方向（正規化済み）を返す。
## from は必ず「狙う本人」のノードを渡すこと（SubViewport 座標を正しく取るため）。
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