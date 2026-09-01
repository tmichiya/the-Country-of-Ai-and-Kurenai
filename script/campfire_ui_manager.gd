extends CanvasLayer
@onready var title_screen_anim: AnimationPlayer = $CenterContainer/TitleScreen/AnimationPlayer
@onready var title_screen_time_label: Label = $CenterContainer/TitleScreen/Control/Time/Label

func set_title_screen_time(time: String) -> void:
	title_screen_time_label.text = time

func show_title_screen() -> void:
	title_screen_anim.play("stage_title")
