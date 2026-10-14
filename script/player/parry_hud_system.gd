extends Control

@onready var ParryHUDParticles : Node2D = $ParryHUDParticles

@export var player: Node2D

func _ready() -> void:
	if not player:
		push_error("Player node not assigned in ParryHUDSystem.")
		return
	
	player.parried.connect(_on_player_parried)

func _on_player_parried() -> void:
	ParryHUDParticles.play_particle()