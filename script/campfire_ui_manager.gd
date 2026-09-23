extends CanvasLayer
@onready var title_screen_anim: AnimationPlayer = $CenterContainer/TitleScreen/AnimationPlayer
@onready var title_screen_time_label: Label = $CenterContainer/TitleScreen/Control/Time/Label

@onready var time_label: Label = get_node_or_null("CenterContainer/HUD/TimeLabel") as Label

func set_title_screen_time(time: String) -> void:
	title_screen_time_label.text = time

func show_title_screen() -> void:
	title_screen_anim.play("stage_title")

func set_time_text(text: String) -> void:
	if time_label == null:
		return
	time_label.text = text