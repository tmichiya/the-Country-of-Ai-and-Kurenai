extends Node

@onready var boss_room: Node2D = $BossRoom
@onready var camp_room: Node2D = $CampfireRoom

var _transitioning := false

func _show_only(active_room: Node) -> void:
	for room in [boss_room, camp_room]:
		room.set_active(room == active_room)

func _on_campfire_requested() -> void:
	if _transitioning:
		return
	_transitioning = true
	GameManager.commit_loop_advance()   # 遷移が確定したここで一度だけループを進める
	await Effects.warp_transition(func():
		_show_only(camp_room)
		camp_room.reset_room()
	)
	_transitioning = false

func _on_next_battle_requested() -> void:
	if _transitioning:
		return
	_transitioning = true
	await Effects.normal_transition(func():
		_show_only(boss_room)
		boss_room.reset_room()
	)
	_transitioning = false

func _on_boss_requested() -> void:
	if _transitioning:
		return
	_transitioning = true
	await Effects.warp_transition(func():
		_show_only(boss_room)
		boss_room.reset_room()
	)
	_transitioning = false

func _ready() -> void:
	GameManager.campfire_requested.connect(_on_campfire_requested)
	GameManager.next_battle_requested.connect(_on_next_battle_requested)
	GameManager.boss_requested.connect(_on_boss_requested)

	_show_only(camp_room)
	camp_room.reset_room()
