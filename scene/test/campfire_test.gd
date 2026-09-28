extends Node

@onready var camp_room: Node2D = $CampfireStage

func _ready() -> void:
	camp_room.set_active(true)
	camp_room.reset_room()
