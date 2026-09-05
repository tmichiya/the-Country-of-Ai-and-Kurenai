extends Node

@onready var boss_room: Node2D = $BossRoom
@onready var camp_room: Node2D = $CampfireRoom

var _transitioning := false

func _show_only(active_room: Node) -> void:
	for room in [boss_room, camp_room]:
		room.set_active(room == active_room)

## 遷移中フラグの唯一の入り口。
## 遷移演出の最中にポーズされると warp の途中で固まって見えるので、
## 同じタイミングでポーズの可否も切り替える。
func _set_transitioning(value: bool) -> void:
	_transitioning = value
	PauseMenu.set_available(not value)

func _on_campfire_requested() -> void:
	if _transitioning:
		return
	_set_transitioning(true)
	await Effects.warp_transition(func():
		_show_only(camp_room)
		camp_room.reset_room()
		boss_room.reset_player_death_effects()
		AudioManager.stop_all_se()
	)
	_set_transitioning(false)

func _on_next_battle_requested() -> void:
	if _transitioning:
		return
	_set_transitioning(true)
	await Effects.normal_transition(func():
		_show_only(boss_room)
		boss_room.reset_room()
		AudioManager.stop_all_se()
	)
	_set_transitioning(false)

func _on_boss_requested() -> void:
	if _transitioning:
		return
	_set_transitioning(true)
	await Effects.warp_transition(func():
		_show_only(boss_room)
		boss_room.reset_room()
		AudioManager.stop_all_se()
	)
	_set_transitioning(false)

func _ready() -> void:
	GameManager.campfire_requested.connect(_on_campfire_requested)
	GameManager.next_battle_requested.connect(_on_next_battle_requested)
	GameManager.boss_requested.connect(_on_boss_requested)

	# このシーン（＝ゲーム本編）にいる間だけ Esc ポーズを有効にする。
	# タイトル／オープニングでは PauseMenu 側が false のままなので反応しない。
	PauseMenu.set_available(true)

	_show_only(camp_room)
	camp_room.reset_room()
