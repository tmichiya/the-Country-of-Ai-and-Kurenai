extends Node

@onready var opening_room: Node2D = $OpeningStage

func _ready() -> void:
	# ルーム切り替えのために、GameManager のシグナルを受け取る。
	opening_room.set_active(true)
	opening_room.reset_room()
