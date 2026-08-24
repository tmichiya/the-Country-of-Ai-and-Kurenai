extends Node

@onready var camp_room: Node2D = $CampfireStage

func _ready() -> void:
	# ルーム切り替えのために、GameManager のシグナルを受け取る。
	camp_room.set_active(true)
	camp_room.reset_room()
