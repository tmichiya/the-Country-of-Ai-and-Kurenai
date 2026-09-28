extends Node2D

@onready var center_container: CenterContainer = $CanvasLayer/CenterContainer
@onready var wave_1_score: PanelContainer = $CanvasLayer/CenterContainer/Result/Wave1Score
@onready var wave_2_score: PanelContainer = $CanvasLayer/CenterContainer/Result/Wave2Score
@onready var wave_3_score: PanelContainer = $CanvasLayer/CenterContainer/Result/Wave3Score
@onready var total_score: PanelContainer = $CanvasLayer/CenterContainer/Result/TotalScore

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	get_viewport().size_changed.connect(_fit_center_container)
	_fit_center_container()

	wave_1_score.set_text(GameManager.format_time(GameManager.wave_times[0]))
	wave_2_score.set_text(GameManager.format_time(GameManager.wave_times[1]))
	wave_3_score.set_text(GameManager.format_time(GameManager.wave_times[2]))
	total_score.set_text(GameManager.format_time(GameManager.get_total_time()))

	animation_player.play("result/show_result")


	animation_player.animation_finished.connect(_on_result_animation_finished)


func _on_result_animation_finished(anim_name: String) -> void:
	if anim_name == "result/show_result":
		GameManager.go_to_title()


func _fit_center_container() -> void:
	center_container.position = Vector2.ZERO
	center_container.size = get_viewport_rect().size

func play_next_chat_se() -> void:
	AudioManager.play_se("next_chat")

func play_bell_1_se() -> void:
	AudioManager.play_se("bell_1")

func play_bell_2_se() -> void:
	AudioManager.play_se("bell_2")
