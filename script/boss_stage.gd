extends Node2D

signal battle_started
signal battle_finished(is_win: bool)

@onready var battle_manager: Node2D = $Battle
@onready var chat_start_area: Area2D = $Battle/EffectLayer/SubViewportContainer/SubViewport/ChatStartArea
@onready var player: CharacterBody2D = $Battle/EffectLayer/SubViewportContainer/SubViewport/Player
@onready var akane: CharacterBody2D = $Battle/EffectLayer/SubViewportContainer/SubViewport/Akane
@onready var ui_manager: CanvasLayer = $Battle/UILayer

enum StageState {
	WALK_IN,
	PRE_TALK,
	BATTLE,
	POST_TALK,
	WALK_OUT
}

var state: StageState
var loop_count: int = 0

func reset_room() -> void:
	print("Resetting boss stage room.")
	state = StageState.WALK_IN
	player.set_process_input(true)
	player.set_physics_process(true)
	battle_manager.reset_battle()
	Camera.set_node_data($Battle/EffectLayer/SubViewportContainer/SubViewport/Camera, $Battle/EffectLayer/SubViewportContainer, $Battle/EffectLayer/SubViewportContainer/SubViewport)
	Camera.reset_target_dictionary()
	Camera.add_target("player", player)
	Camera.add_target("akane", akane)
	Camera.set_state(Camera.CameraState.FOLLOW_TARGET)
	Camera.set_current_target("player")
	Dialogue.reset_speakers()
	Dialogue.add_speaker("player", player)
	Dialogue.add_speaker("akane", akane)

func _on_chat_start_area_entered() -> void:
	state = StageState.PRE_TALK
	battle_started.emit()

func _on_battle_finished(is_win: bool) -> void:
	if is_win:
		battle_finished.emit(true)
		
		state = StageState.POST_TALK
	else:
		GameManager.go_to_campfire()

func _on_loop_advanced(loop_c: int) -> void:
	loop_count = loop_c

func set_active(active: bool) -> void:
	# UIを含めた表示非表示
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	ui_manager.visible = active

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if battle_manager:
		battle_manager.battle_finished.connect(_on_battle_finished)
	chat_start_area.entered.connect(_on_chat_start_area_entered)

	GameManager.loop_advanced.connect(_on_loop_advanced)

	reset_room()