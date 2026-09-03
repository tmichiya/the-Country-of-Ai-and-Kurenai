extends Node2D

signal battle_started
signal battle_finished(is_win: bool)

@onready var battle_manager: Node2D = $Battle
@onready var center_container: CenterContainer = $Battle/CenterContainer
@onready var campfire_area: Area2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/CampfireArea
@onready var player: CharacterBody2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/Player
@onready var hakubo: CharacterBody2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/Hakubo
@onready var ui_manager: CanvasLayer = $Battle/UILayer
@onready var event_collision: StaticBody2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/StageBackground/EventCollision

@onready var chat_start_area: Area2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/ChatStartArea
@onready var chat_1_area: Area2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/Chat1Area
@onready var zoom_out_area: Area2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/ZoomOutArea

@onready var lighting_night: CanvasModulate = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/TimeLighting/Night
@onready var lighting_morning: CanvasModulate = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/TimeLighting/Morning
@onready var lighting_dawn: CanvasModulate = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/TimeLighting/Dawn
@onready var lighting_predawn: CanvasModulate = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/TimeLighting/Predawn
@onready var lighting_evening: CanvasModulate = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/TimeLighting/Evening

@onready var hud: Control = $Battle/UILayer/CenterContainer/HUD

enum StageState {
	WALK_IN,
	PRE_TALK,
	BATTLE,
	POST_TALK,
	WALK_OUT,
	PLAYER_DEAD
}

var state: StageState
var loop_count: int = 0

var is_first_intro_chat: bool = true
var is_first_pre_chat: bool = true
var is_first_post_chat: bool = true

func reset_room() -> void:
	state = StageState.WALK_IN
	player.set_process_to(true)
	battle_manager.reset_battle()
	Camera.set_node_data($Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/Camera, $Battle/CenterContainer/EffectLayer/SubViewportContainer, $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport)
	Camera.reset_target_dictionary()
	Camera.add_target("player", player)
	Camera.set_state(Camera.CameraState.FOLLOW_TARGET)
	Camera.set_current_target("player")
	Camera.set_offset(Vector2(0, 0), 0)
	Camera.set_zoom_value(Vector2(1.5, 1.5), 0.1)
	Camera.map_rect = Rect2(Vector2.ZERO, Vector2(1200, 1750))
	Dialogue.reset_speakers()
	Dialogue.add_speaker("player", player)
	Dialogue.add_speaker("hakubo", hakubo)
	Dialogue.load_battle_json()
	chat_start_area.set_monitoring_active(true)
	chat_1_area.set_monitoring_active(true)
	zoom_out_area.set_monitoring_active(true)
	campfire_area.set_monitoring_active(true)
	_activate_lighting()
	set_hud_visible(false)
	event_collision.collision_layer = 0

	_start_camera_motion()

func reset_player_death_effects() -> void:
	battle_manager.reset_player_death_effects()

func _activate_lighting() -> void:
	if loop_count == 0:
		lighting_night.visible = false
		lighting_morning.visible = true
		lighting_dawn.visible = false
		lighting_predawn.visible = false
		lighting_evening.visible = false
	elif loop_count == 1:
		lighting_night.visible = true
		lighting_morning.visible = false
		lighting_dawn.visible = false
		lighting_predawn.visible = false
		lighting_evening.visible = false
	elif loop_count == 2:
		lighting_night.visible = false
		lighting_morning.visible = false
		lighting_dawn.visible = true
		lighting_predawn.visible = false
		lighting_evening.visible = false

func _start_camera_motion() -> void:
	Camera.add_target("hakubo", hakubo)
	player.set_process_to(false)
	Camera.set_current_target("hakubo")
	await get_tree().create_timer(3.0, true, false, true).timeout

	_show_title_screen()

	Camera.set_follow_speed(2.0)
	Camera.set_current_target("player")
	player.set_process_to(true)
	await get_tree().create_timer(2.0, true, false, true).timeout
	Camera.set_follow_speed(8.0)
	Camera.reset_target_dictionary()
	Camera.add_target("player", player)

func _show_title_screen() -> void:
	ui_manager.set_title_screen_time(["早朝", "深夜", "夜明け前"][loop_count])
	ui_manager.show_title_screen()

func _get_conversation_tag() -> String:
	return "loop%d" % loop_count

# 実際に戦闘を始めるスイッチ。会話の有無に関係なくここを通す。
func _begin_battle() -> void:
	state = StageState.BATTLE
	set_hud_visible(true)
	battle_started.emit()
	player.mana_component.restore(100.0)

func _on_chat_start_area_entered() -> void:
	state = StageState.PRE_TALK
	event_collision.collision_layer = 1
	Camera.add_target("hakubo", hakubo)
	if is_first_pre_chat:
		is_first_pre_chat = false
		Dialogue.play_conversation(_get_conversation_tag() + "_pre")
		# 会話が終わると _on_dialogue_finished("..._pre") 経由で _begin_battle() が呼ばれる
	else:
		# 会話は既に見たので飛ばして直接戦闘を開始する。
		# （死亡後のリトライなど、ループが進まず is_first_pre_chat が false のまま再入場したケース）
		_begin_battle()
	campfire_area.set_monitoring_active(true)

func _on_chat_1_area_entered() -> void:
	if is_first_intro_chat:
		is_first_intro_chat = false
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
		if is_first_post_chat:
			is_first_post_chat = false
			Dialogue.play_conversation(_get_conversation_tag() + "_post")
		GameManager.commit_loop_advance()   # 遷移が確定したここで一度だけループを進める
	else:
		print("Player dead. Going to campfire.")
		GameManager.go_to_campfire()

func _on_dialogue_finished(conversation_tag: String) -> void:
	if conversation_tag.ends_with("pre"):
		_begin_battle()
	elif conversation_tag.ends_with("post"):
		state = StageState.WALK_OUT
		player.set_process_to(false)

		print("Post-talk conversation finished. Loop count: %d" % loop_count)

		# loop3は最終ループなので、戦闘後の会話が終わったらエンディングに遷移する。
		if loop_count == 3:
			GameManager.go_to_ending()
		else:
			GameManager.go_to_campfire()

func _on_loop_advanced(loop_c: int) -> void:
	loop_count = loop_c
	is_first_intro_chat = true
	is_first_pre_chat = true
	is_first_post_chat = true

func set_active(active: bool) -> void:
	# UIを含めた表示非表示
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	ui_manager.visible = active

func set_hud_visible(visible: bool) -> void:
	hud.visible = visible

func _fit_center_container() -> void:
	# CenterContainer をウィンドウ全体に広げる（親が Node2D でアンカーが効かないためコードで設定）。
	# CenterContainer が中の 480x360 の箱を正しく中央に配置する。
	center_container.position = Vector2.ZERO
	center_container.size = get_viewport_rect().size

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
