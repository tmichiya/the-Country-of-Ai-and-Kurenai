extends Control

@onready var skip_animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	visible = false

func play_skip_animation() -> void:
	skip_animation_player.play("skip_animation")

func stop_skip_animation() -> void:
	skip_animation_player.stop()
	visible = false