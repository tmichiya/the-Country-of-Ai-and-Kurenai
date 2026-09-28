extends CanvasLayer

signal opened
signal closed

@onready var root: Control = $Root
@onready var resume_button: Control = $Root/Menu/Resume
@onready var to_title_button: Control = $Root/Menu/ToTitle
@onready var to_compfire: Control = $Root/Menu/ToCampfire

var _available: bool = false
var _is_open: bool = false
## 「タイトルへ」処理中の多重発火ガード
var _quitting: bool = false
var _go_to_campfire: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	root.modulate.a = 1.0
	resume_button.button_pressed.connect(_on_resume_pressed)
	to_title_button.button_pressed.connect(_on_to_title_pressed)
	to_compfire.button_pressed.connect(_on_to_campfire_pressed)


## ポーズを許可するかを外から切り替える。
func set_available(value: bool) -> void:
	_available = value
	if not value and _is_open:
		_close()


func is_open() -> bool:
	return _is_open


func _unhandled_input(event: InputEvent) -> void:
	if _quitting:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if not _available and not _is_open:
		return
	# 下のノードに Esc を渡さない。
	get_viewport().set_input_as_handled()
	if _is_open:
		_close()
	else:
		_open()


func _open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	root.modulate.a = 1.0
	get_tree().paused = true
	resume_button.grab_button_focus()
	opened.emit()


func _close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	closed.emit()
	await get_tree().process_frame
	if not _is_open and not _quitting:
		get_tree().paused = false


func _on_resume_pressed() -> void:
	AudioManager.play_se("button_pressed")
	_close()


func _on_to_title_pressed() -> void:
	if _quitting:
		return
	AudioManager.play_se("button_pressed")
	_quitting = true
	_available = false

	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.3)
	await tw.finished

	# Effects は通常 PAUSABLE なので、暗転の間だけ止まらないノードに昇格。
	var prev_mode: int = Effects.process_mode
	Effects.process_mode = Node.PROCESS_MODE_ALWAYS
	Effects.set_fade_color(Vector3(0.05, 0.05, 0.05))
	Effects.set_fade_alpha(1.0)
	await Effects.fade_in(1.0)

	# 暗転しきってから解除。ここで戻さないと次のシーンまで止まったままになる。
	_is_open = false
	visible = false
	get_tree().paused = false
	Engine.time_scale = 1.0  # スロー演出中にポーズしていた場合の保険
	Effects.process_mode = prev_mode

	await GameManager.return_to_opening()
	root.modulate.a = 1.0
	_quitting = false
	
func _on_to_campfire_pressed() -> void:
	print("campfire button pressed")
	GameManager.go_to_campfire()
	
