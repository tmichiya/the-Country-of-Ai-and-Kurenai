extends Node
@export var loop_count: int = 0
@export var test_battle_scene: bool = true

@onready var boss_room: Node2D = $BossStage
@onready var campfire_room: Node2D = $CampfireStage

func _ready() -> void:
	for i in range(loop_count):
		GameManager.commit_loop_advance()

	if test_battle_scene:
		boss_room.set_active(true)
		boss_room.reset_room()
		campfire_room.set_active(false)
		campfire_room.visible = false
	else:
		campfire_room.set_active(true)
		campfire_room.reset_room()
		boss_room.set_active(false)
		boss_room.visible = false

