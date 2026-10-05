extends Node2D

signal start_opening_scene

@onready var reset_data_select_box: Node2D = $CanvasLayer/Control/ResetDataSelectBox
@onready var difficulty_select_box: Node2D = $CanvasLayer/Control/DifficultySelectBox

func _ready() -> void:
	var start_button_system: Control = $CanvasLayer/Control/VBoxContainer/Start
	var start_easy_mode_button_system: Control = $CanvasLayer/Control/VBoxContainer/StartEasyMode
	var quit_game_button_system: Control = $CanvasLayer/Control/QuitGame
	start_button_system.button_pressed.connect(_on_normal_mode_button_pressed)
	start_easy_mode_button_system.button_pressed.connect(_on_easy_mode_button_pressed)
	quit_game_button_system.button_pressed.connect(_on_quit_game_button_pressed)

	var restart_or_resume_game_button_connecter: VBoxContainer = $CanvasLayer/Control/RestartOrResumeGame
	restart_or_resume_game_button_connecter.button_pressed.connect(_on_restart_or_resume_game_button_pressed)

	reset_data_select_box.hide_box()
	reset_data_select_box.set_left_button_text("はい")
	reset_data_select_box.set_right_button_text("いいえ")
	reset_data_select_box.set_text("本当に初めからやり直しますか？\nセーブデータは上書きされます。")
	reset_data_select_box.left_button_pressed.connect(_on_restart_confirmed)
	reset_data_select_box.right_button_pressed.connect(_on_restart_canceled)

	difficulty_select_box.hide_box()
	difficulty_select_box.set_left_button_text("ノーマル")
	difficulty_select_box.set_right_button_text("イージー")
	difficulty_select_box.set_text("難易度を選択してください")
	difficulty_select_box.left_button_pressed.connect(_on_normal_mode_button_pressed)
	difficulty_select_box.right_button_pressed.connect(_on_easy_mode_button_pressed)

	start_button_system.grab_button_focus()

func _start_game() -> void:
	GameManager.load_save_data()

	if GameManager.current_stage == GameManager.Stage.OPENING:
		Effects.set_fade_color(Vector3(1.0, 1.0, 1.0))
		Effects.set_fade_alpha(1.0)
		Effects.set_visible_fade(true)
		await Effects.fade_in(1.0)
		start_opening_scene.emit()

		queue_free()
		await Effects.fade_out(1.0)

		Effects.set_fade_color(Vector3(0.05, 0.05, 0.05))
		Effects.set_fade_alpha(1.0)

func _on_normal_mode_button_pressed() -> void:
	AudioManager.play_se("game_start")
	GameManager.reset_save_data()
	GameManager.set_easy_mode(false)
	GameManager.save_game()
	_start_game()

func _on_easy_mode_button_pressed() -> void:
	AudioManager.play_se("game_start")
	GameManager.reset_save_data()
	GameManager.set_easy_mode(true)
	GameManager.save_game()
	_start_game()

func _on_quit_game_button_pressed(_button: Control) -> void:
	GameManager.request_quit_game()

func _on_restart_confirmed() -> void:
	AudioManager.play_se("button_pressed")
	difficulty_select_box.display_box()

func _on_restart_canceled() -> void:
	AudioManager.play_se("button_pressed")
	reset_data_select_box.hide_box()

func _on_restart_or_resume_game_button_pressed(button: Control) -> void:
	if button.name == "Restart":
		AudioManager.play_se("button_pressed")
		reset_data_select_box.display_box()
	elif button.name == "Resume":
		AudioManager.play_se("game_start")
		_start_game()
