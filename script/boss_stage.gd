extends Node2D

signal battle_started
signal battle_finished(is_win: bool)

@onready var battle_manager: Node2D = $Battle
@onready var center_container: CenterContainer = $Battle/CenterContainer
@onready var campfire_area: Area2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/CampfireArea
@onready var player: CharacterBody2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/Player
@onready var akane: CharacterBody2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/Akane
@onready var ui_manager: CanvasLayer = $Battle/UILayer
@onready var event_collision: StaticBody2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/StageBackground/EventCollision

@onready var chat_start_area: Area2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/ChatStartArea
@onready var chat_1_area: Area2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/Chat1Area
@onready var zoom_out_area: Area2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/ZoomOutArea

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
	player.set_process_to(true)
	battle_manager.reset_battle()
	Camera.set_node_data($Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/Camera, $Battle/CenterContainer/EffectLayer/SubViewportContainer, $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport)
	Camera.reset_target_dictionary()
	Camera.add_target("player", player)
	Camera.set_state(Camera.CameraState.FOLLOW_TARGET)
	Camera.set_current_target("player")
	Camera.set_offset(Vector2(0, 0), 0)
	Camera.set_zoom_value(Vector2(2, 2), 0.1)
	Camera.map_rect = Rect2(Vector2.ZERO, Vector2(1200, 1750))
	Dialogue.reset_speakers()
	Dialogue.add_speaker("player", player)
	Dialogue.add_speaker("akane", akane)
	Dialogue.load_battle_json()
	print("Resetting room. Loop count: %d" % loop_count)
	chat_start_area.set_monitoring_active(true)
	chat_1_area.set_monitoring_active(true)
	zoom_out_area.set_monitoring_active(true)
	campfire_area.set_monitoring_active(true)

	_start_camera_motion()

func _start_camera_motion() -> void:
	Camera.add_target("akane", akane)
	player.set_process_to(false)
	Camera.set_current_target("akane")
	await get_tree().create_timer(3.0, true, false, true).timeout
	Camera.set_follow_speed(2.0)
	Camera.set_current_target("player")
	player.set_process_to(true)
	await get_tree().create_timer(2.0, true, false, true).timeout
	Camera.set_follow_speed(8.0)
	Camera.reset_target_dictionary()
	Camera.add_target("player", player)

func _get_conversation_tag() -> String:
	return "loop%d" % loop_count

func _on_chat_start_area_entered() -> void:
	state = StageState.PRE_TALK
	event_collision.collision_layer = 1
	Camera.add_target("akane", akane)
	Dialogue.play_conversation(_get_conversation_tag() + "_pre")
	campfire_area.set_monitoring_active(true)

func _on_chat_1_area_entered() -> void:
	Dialogue.play_conversation(_get_conversation_tag() + "_intro")

func _on_campfire_area_entered() -> void:
	GameManager.go_to_campfire()

func _on_zoom_out_area_entered() -> void:
	Camera.set_zoom_value(Vector2(1, 1), 1.2)

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
		Camera.reset_target_dictionary()
		Camera.add_target("player", player)
		Camera.set_current_target("player")
		Camera.state = Camera.CameraState.FOLLOW_TARGET
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
	campfire_area.entered.connect(_on_campfire_area_entered)

	chat_start_area.entered.connect(_on_chat_start_area_entered)
	chat_1_area.entered.connect(_on_chat_1_area_entered)
	zoom_out_area.entered.connect(_on_zoom_out_area_entered)
	Dialogue.finished.connect(_on_dialogue_finished)

	GameManager.loop_advanced.connect(_on_loop_advanced)

	# 4:3のゲーム画面をウィンドウ中央に置くため、CenterContainer を実ウィンドウサイズに合わせる。
	# これで中央寄せがレイアウトで完結し、描画位置と入力(マウス)判定の矩形が一致する。
	get_viewport().size_changed.connect(_fit_center_container)
	_fit_center_container()

func _fit_center_container() -> void:
	# CenterContainer をウィンドウ全体に広げる（親が Node2D でアンカーが効かないためコードで設定）。
	# CenterContainer が中の 480x360 の箱を正しく中央に配置する。
	center_container.position = Vector2.ZERO
	center_container.size = get_viewport_rect().size
