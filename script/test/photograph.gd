extends Node2D

@onready var center_container : CenterContainer = $CenterContainer

@export var player : CharacterBody2D

func _ready() -> void:
	get_viewport().size_changed.connect(_fit_center_container)
	_fit_center_container()


func _process(delta: float) -> void:
	player.mana_component.restore(100)

func _fit_center_container() -> void:
	center_container.position = Vector2.ZERO
	center_container.size = get_viewport_rect().size
