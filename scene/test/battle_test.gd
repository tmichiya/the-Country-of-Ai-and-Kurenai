extends Node
@export var loop_count: int = 0
@onready var boss_room: Node2D = $BossStage

func _ready() -> void:
	for i in range(loop_count):
		GameManager.commit_loop_advance()

	boss_room.set_active(true)
	boss_room.reset_room()
