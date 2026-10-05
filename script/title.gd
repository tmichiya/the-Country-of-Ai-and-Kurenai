extends Node2D

signal start_opening_scene

func _ready() -> void:
	var start_button_system: Control = $CanvasLayer/Control/VBoxContainer/Start
	var start_easy_mode_button_system: Control = $CanvasLayer/Control/VBoxContainer/StartEasyMode
	var quit_game_button_system: Control = $CanvasLayer/Control/VBoxContainer/QuitGame
	start_button_system.button_pressed.connect(_start_game)
	start_easy_mode_button_system.button_pressed.connect(_on_easy_mode_button_pressed)
	quit_game_button_system.button_pressed.connect(_on_quit_game_button_pressed)

	start_button_system.grab_button_focus()

func _start_game() -> void:
	AudioManager.play_se("game_start")

	GameManager.set_easy_mode(false)

	Effects.set_fade_color(Vector3(1.0, 1.0, 1.0))
	Effects.set_fade_alpha(1.0)
	Effects.set_visible_fade(true)
	await Effects.fade_in(1.0)

	GameManager.load_save_data()

	if GameManager.current_stage == GameManager.Stage.OPENING:
		start_opening_scene.emit()

	queue_free()
	await Effects.fade_out(1.0)

	Effects.set_fade_color(Vector3(0.05, 0.05, 0.05))
	Effects.set_fade_alpha(1.0)

func _on_easy_mode_button_pressed() -> void:
	GameManager.set_easy_mode(true)

	_start_game()

func _on_quit_game_button_pressed() -> void:
	GameManager.request_quit_game()
