extends Node2D

signal battle_started
signal battle_finished(is_win: bool)

@export var game_manager: Node2D

@onready var battle_manager: Node2D = $BattleManager
@onready var battle_start_area: Area2D = $Battle/EffectLayer/SubViewportContainer/SubViewport/BattleStartArea

enum StageState {
	WALK_IN,
	PRE_TALK,
	BATTLE,
	POST_TALK,
	WALK_OUT
}

var state: StageState

func reset() -> void:
	state = StageState.WALK_IN

func _on_battle_start_area_entered(body: CharacterBody2D) -> void:
	if not body.is_in_group("player"):
		return
	print("test")
	state = StageState.BATTLE
	battle_started.emit()

func _on_battle_finished(is_win: bool) -> void:
	if is_win:
		battle_finished.emit(true)
		state = StageState.POST_TALK
	else:
		game_manager.go_to_campfire()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if battle_manager:
		battle_manager.battle_finished.connect(_on_battle_finished)
	battle_start_area.entered.connect(_on_battle_start_area_entered)

	reset()
