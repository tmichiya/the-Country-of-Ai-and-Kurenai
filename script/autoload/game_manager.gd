extends Node

signal loop_advanced(loop_count: int)
signal campfire_requested
signal boss_requested
signal next_battle_requested

@onready var boss_room: Node2D = $BossRoom

var loop_count: int = 0

func go_to_campfire() -> void:
	campfire_requested.emit()

func advance_loop_and_fight() -> void:
	loop_count += 1
	loop_advanced.emit(loop_count)
	next_battle_requested.emit()

func go_to_boss() -> void:
	boss_requested.emit()

func wait_for_confirm() -> void:
	await get_tree().process_frame
	while not Input.is_action_just_pressed("ui_accept"):
		await get_tree().process_frame
