extends Node2D

@onready var boss_room: Node2D = $BossRoom
@onready var camp_room: Node2D = $CampfireRoom

var _transitioning := false

func _ready() -> void:
	GameManager.campfire_requested.connect(_on_campfire_requested)
	GameManager.next_battle_requested.connect(_on_next_battle_requested)
	GameManager.boss_requested.connect(_on_boss_requested)

	_show_only(boss_room)
	boss_room.reset_room()

func _show_only(active_room: Node) -> void:
	for room in [boss_room, camp_room]:
		var is_active : bool = (room == active_room)
		room.visible = is_active
		# visible=false は描画を止めるだけで処理は止まらないので、
		# process_mode も合わせて止める（裏で動き続けるのを防ぐ）
		room.process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED

func _on_campfire_requested() -> void:
	if _transitioning:
		return
	_transitioning = true
	await Effects.warp_transition(func():
		_show_only(camp_room)
		camp_room.reset_room()
	)
	_transitioning = false

func _on_next_battle_requested() -> void:
	if _transitioning:
		return
	_transitioning = true
	await Effects.warp_transition(func():
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
