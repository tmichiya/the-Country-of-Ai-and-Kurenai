extends Node2D

signal battle_started
signal battle_finished(is_win: bool)

@onready var battle_manager: Node2D = $Battle
@onready var battle_start_area: Area2D = $Battle/EffectLayer/SubViewportContainer/SubViewport/BattleStartArea
@onready var player: CharacterBody2D = $Battle/EffectLayer/SubViewportContainer/SubViewport/Player
@onready var ui_manager: CanvasLayer = $Battle/UILayer


enum StageState {
	WALK_IN,
	PRE_TALK,
	BATTLE,
	POST_TALK,
	WALK_OUT
}

var state: StageState

func reset_room() -> void:
	state = StageState.WALK_IN
	player.set_process_input(true)
	player.set_physics_process(true)
	battle_manager.reset_battle()

func _on_battle_start_area_entered() -> void:
	state = StageState.BATTLE
	battle_started.emit()

func _on_battle_finished(is_win: bool) -> void:
	if is_win:
		battle_finished.emit(true)
		
		state = StageState.POST_TALK

		# test
		GameManager.go_to_campfire()
	else:
		GameManager.go_to_campfire()

func set_active(active: bool) -> void:
	# UIを含めた表示非表示
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	ui_manager.visible = active

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if battle_manager:
		battle_manager.battle_finished.connect(_on_battle_finished)
	battle_start_area.entered.connect(_on_battle_start_area_entered)

	reset_room()
