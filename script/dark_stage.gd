extends Sprite2D

@export var hakubo : CharacterBody2D
@onready var animiation_player : AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	if not hakubo:
		push_error("DarkStage: hakubo is not exist!")
		return

	hakubo.attack_parried.connect(_on_hakubo_parried)

func _on_hakubo_parried() -> void:
	animiation_player.play("dark_stage_alpha")
