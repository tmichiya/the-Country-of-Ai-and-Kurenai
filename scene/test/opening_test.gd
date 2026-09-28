extends Node

@onready var opening_room: Node2D = $OpeningStage

func _ready() -> void:
	opening_room.set_active(true)
	opening_room.reset_room()
