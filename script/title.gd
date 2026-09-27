extends Node2D

signal start_opening_scene

func _ready() -> void:
	var start_button_system: Control = $CanvasLayer/Control/VBoxContainer/Start
	var start_easy_mode_button_system: Control = $CanvasLayer/Control/VBoxContainer/StartEasyMode
	start_button_system.button_pressed.connect(_on_start_button_pressed)
	start_easy_mode_button_system.button_pressed.connect(_on_easy_mode_button_pressed)

	Effects.set_fade_color(Vector3(1.0, 1.0, 1.0))
	Effects.set_fade_parameter(0.0)
	Effects.set_fade_alpha(0.2)
	Effects.set_visible_fade(true)

func _on_start_button_pressed() -> void:
	AudioManager.play_se("game_start")

	GameManager.easy_mode = false

	_fade_out_title_scene()
	start_opening_scene.emit()

func _on_easy_mode_button_pressed() -> void:
	AudioManager.play_se("game_start")

	GameManager.easy_mode = true

	_fade_out_title_scene()
	start_opening_scene.emit()

func _fade_out_title_scene() -> void:
	var control: Control = $CanvasLayer/Control
	Effects.fade_out(1.0, 0.2)
	var tween: Tween = create_tween()
	tween.tween_property(control, "modulate:a", 0.0, 1.0)
	await tween.finished
	Effects.set_fade_color(Vector3(0.05, 0.05, 0.05))
	Effects.set_fade_alpha(1.0)
	queue_free()
