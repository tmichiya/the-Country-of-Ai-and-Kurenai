extends Node2D

signal battle_started
signal battle_finished(is_win: bool)

@onready var battle_manager: Node2D = $Battle
@onready var chat_start_area: Area2D = $Battle/EffectLayer/SubViewportContainer/SubViewport/ChatStartArea
@onready var campfire_area: Area2D = $Battle/EffectLayer/SubViewportContainer/SubViewport/CampfireArea
@onready var player: CharacterBody2D = $Battle/EffectLayer/SubViewportContainer/SubViewport/Player
@onready var akane: CharacterBody2D = $Battle/EffectLayer/SubViewportContainer/SubViewport/Akane
@onready var ui_manager: CanvasLayer = $Battle/UILayer
@onready var event_collision: StaticBody2D = $Battle/EffectLayer/SubViewportContainer/SubViewport/StageBackground/EventCollision

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
	print("Resetting room. Loop count: %d" % loop_count)
	chat_start_area.set_monitoring_active(true)
	campfire_area.set_monitoring_active(true)

func _get_conversation_tag() -> String:
	return "loop%d" % loop_count

func _on_chat_start_area_entered() -> void:
	state = StageState.PRE_TALK
	event_collision.collision_layer = 1
	Dialogue.play_conversation(_get_conversation_tag() + "_pre")
	campfire_area.set_monitoring_active(true)

func _on_campfire_area_entered() -> void:
	GameManager.go_to_campfire()

func _on_battle_finished(is_win: bool) -> void:
	if is_win:
		battle_finished.emit(true)
		state = StageState.POST_TALK
		event_collision.collision_layer = 0
		Dialogue.play_conversation(_get_conversation_tag() + "_post")
	else:
		GameManager.go_to_campfire()

func _on_dialogue_finished(conversation_tag: String) -> void:
	if conversation_tag.ends_with("pre"):
		state = StageState.BATTLE
		battle_started.emit()
	elif conversation_tag.ends_with("post"):
		state = StageState.WALK_OUT
		akane.visible = false

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
	campfire_area.entered.connect(_on_campfire_area_entered)

	Dialogue.finished.connect(_on_dialogue_finished)

	GameManager.loop_advanced.connect(_on_loop_advanced)

	# debug


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("dash"):
		print("campfire_area _arm : %s" % campfire_area._armed)
