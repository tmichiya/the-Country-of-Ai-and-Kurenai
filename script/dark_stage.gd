extends Sprite2D

@export var hakubo : CharacterBody2D
@onready var animation_player : AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	if not hakubo:
		push_error("DarkStage: hakubo is not exist!")
		return

	hakubo.attack_parried.connect(_on_hakubo_parried)

func _on_hakubo_parried() -> void:
	animation_player.play("dark_stage_alpha")

func display() -> void:
	if animation_player.is_playing():
		animation_player.stop()
	
	visible = true
	modulate.a = 1.0