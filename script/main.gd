extends Node

@onready var boss_room: Node2D = $BossRoom
@onready var camp_room: Node2D = $CampfireRoom

var _transitioning := false

func _show_only(active_room: Node) -> void:
	for room in [boss_room, camp_room]:
		room.set_active(room == active_room)

## 遷移中フラグの唯一の入り口。
## ポーズの可否も切り替える。
func _set_transitioning(value: bool) -> void:
	_transitioning = value
	#「踏んだら遷移」の側からも遷移中かどうかを見られるようにする
	GameManager.set_transitioning(value)
	PauseMenu.set_available(not value)

func _on_campfire_requested() -> void:
	print("[main]: Campfire requested")
	if _transitioning:
		return
	_set_transitioning(true)
	await Effects.warp_transition(func():
		print("[main]: Transitioning to campfire room")
		_show_only(camp_room)
		camp_room.reset_room()
		boss_room.reset_player_death_effects()
		AudioManager.stop_all_se()
	)
	_set_transitioning(false)

func _on_boss_requested_on_warp_transition() -> void:
	if _transitioning:
		return
	_set_transitioning(true)
	await Effects.warp_transition(func():
		_show_only(boss_room)
		boss_room.reset_room()
		boss_room.reset_player_death_effects()
		AudioManager.stop_all_se()
	)
	_set_transitioning(false)

func _on_boss_requested_on_normal_transition() -> void:
	if _transitioning:
		return
	_set_transitioning(true)
	await Effects.normal_transition(func():
		_show_only(boss_room)
		boss_room.reset_room()
		boss_room.reset_player_death_effects()
		AudioManager.stop_all_se()
	)
	_set_transitioning(false)

func _ready() -> void:
	GameManager.campfire_requested.connect(_on_campfire_requested)
	GameManager.boss_requested_on_warp_transition.connect(_on_boss_requested_on_warp_transition)
	GameManager.boss_requested_on_normal_transition.connect(_on_boss_requested_on_normal_transition)

	PauseMenu.set_available(true)

	var current_stage = GameManager.get_current_stage()
	if current_stage == GameManager.Stage.CAMPFIRE:
		_show_only(camp_room)
		camp_room.reset_room()
	elif current_stage == GameManager.Stage.BOSS:
		_show_only(boss_room)
		boss_room.reset_room()
	else:
		# Stage.CAMPFIRE or Stage.BOSS 以外の値の時は、Stage.OPENINGからの遷移のため
		# Stage.CAMPFIRE に遷移する。
		_show_only(camp_room)
		camp_room.reset_room()
