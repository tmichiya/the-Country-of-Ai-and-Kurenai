extends Node2D
## 焚火ステージ（歩けるルーム版）。
## ・焚火に近づく → 決定キーでスキル画面（仮）の開閉
## ・奥の地点（WarpArea）に到達 → 次のボス戦へ（GameManager 経由）

@export var player: CharacterBody2D
@export var player_spawn: Marker2D
@export var tadeai: Node2D

@onready var title : Node2D = $Title

@onready var camera: Camera2D = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/Camera

@onready var center_container: CenterContainer = $CenterContainer

@onready var chat_start_area: Area2D = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/ChatStartArea
@onready var warp_area: Area2D = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/WarpArea
@onready var block_area: Area2D = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/BlockArea
@onready var chat_pre_area: Area2D = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/ChatPreArea

var player_in_bonfire_range := false
var loop_count: int = 0

func _ready() -> void:
	chat_start_area.entered.connect(_on_chat_start_entered)
	warp_area.entered.connect(_on_warp_area_entered)
	block_area.entered.connect(_on_block_area_entered)
	block_area.exited.connect(_on_block_area_exited)
	chat_pre_area.entered.connect(_on_chat_pre_area_entered)
	title.start_opening_scene.connect(_start_opening_scene)

	# 4:3のゲーム画面をウィンドウ中央に置くため、CenterContainer を実ウィンドウサイズに合わせる。
	# これで中央寄せがレイアウトで完結し、描画位置と入力(マウス)判定の矩形が一致する。
	get_viewport().size_changed.connect(_fit_center_container)
	_fit_center_container()

	reset_room()
	set_active(true)

var bird_se_timer := 0.0
var bird_se_interval := 1.0
func _process(delta: float) -> void:
	bird_se_timer += delta
	if bird_se_timer >= bird_se_interval:
		bird_se_timer = 0.0
		bird_se_interval = randf_range(6.0, 10.0)
		AudioManager.play_random_bird_se()

func _start_opening_scene() -> void:
	_start_camera_motion()

func _on_chat_start_entered() -> void:
	Camera.reset_target_dictionary()
	Camera.add_target("player", player)
	Camera.add_target("tadeai", tadeai)
	player.set_process_to(false)
	player.stop_movement("fade_in")
	Camera.set_follow_speed(8.0)
	Camera.set_offset(Vector2(0, 0), 2.0)
	block_area.set_monitoring_active(false)
	await Dialogue.play_conversation("opening")
	Camera.set_offset(Vector2(0, -80), 2.0)
	await get_tree().create_timer(1.0, true, false, true).timeout
	Camera.set_follow_speed(8.0)

func _on_warp_area_entered() -> void:
	player.set_process_to(false)
	player.stop_movement("fade_in")
	GameManager.change_scene_to("main")

func _on_block_area_entered() -> void:
	Camera.set_current_target("player")
	player.set_process_to(false)
	await Dialogue.play_conversation("block_area")
	player.set_process_to(false)
	await Effects.fade_in(0.5)
	player.global_position = player_spawn.global_position
	Camera.brif_camera = true
	await Effects.fade_out(0.5)
	player.set_process_to(true)

func _on_block_area_exited() -> void:
	block_area.set_monitoring_active(true)

func _on_chat_pre_area_entered() -> void:
	Camera.reset_target_dictionary()
	Camera.add_target("player", player)
	Dialogue.play_conversation("chat_pre")

func _fit_center_container() -> void:
	# CenterContainer をウィンドウ全体に広げる（親が Node2D でアンカーが効かないためコードで設定）。
	# CenterContainer が中の 480x360 の箱を正しく中央に配置する。
	center_container.position = Vector2.ZERO
	center_container.size = get_viewport_rect().size

func set_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	camera.enabled = active

func _start_camera_motion() -> void:
	player.set_process_to(false)
	Camera.set_current_target("tadeai")
	await get_tree().create_timer(3.0, true, false, true).timeout
	Camera.set_follow_speed(2.0)
	Camera.set_current_target("player")
	Camera.set_offset(Vector2(0, -50), 0)
	player.set_process_to(true)
	await get_tree().create_timer(2.0, true, false, true).timeout
	Camera.set_follow_speed(8.0)


func reset_room() -> void:
	player.reset()
	player.global_position = player_spawn.global_position
	Camera.set_node_data($CenterContainer/EffectLayer/SubViewportContainer/SubViewport/Camera, $CenterContainer/EffectLayer/SubViewportContainer, $CenterContainer/EffectLayer/SubViewportContainer/SubViewport)
	Camera.reset_target_dictionary()
	Camera.add_target("player", player)
	Camera.add_target("tadeai", tadeai)
	Camera.set_current_target("tadeai")
	Camera.set_state(Camera.CameraState.FOLLOW_TARGET)
	Camera.set_zoom_value(Vector2(1.75, 1.75), 0.1)
	Camera.map_rect = Rect2(Vector2.ZERO, Vector2(280, 700))
	Dialogue.reset_speakers()
	Dialogue.add_speaker("player", player)
	Dialogue.add_speaker("tadeai", tadeai)
	Dialogue.load_opening_json()

	player.set_process_to(false)

	AudioManager.play_bgm(AudioManager.BGM_TITLE, 0.5, true)