extends Node2D

@export var player: CharacterBody2D
@export var hakubo: Sprite2D
@export var player_spawn: Marker2D

@onready var ui_layer: CanvasLayer = $UILayer
@onready var camera: Camera2D = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/Camera

@onready var center_container: CenterContainer = $CenterContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 4:3のゲーム画面をウィンドウ中央に置くため、CenterContainer を実ウィンドウサイズに合わせる。
	# これで中央寄せがレイアウトで完結し、描画位置と入力(マウス)判定の矩形が一致する。
	get_viewport().size_changed.connect(_fit_center_container)
	_fit_center_container()

	reset_room()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _fit_center_container() -> void:
	# CenterContainer をウィンドウ全体に広げる（親が Node2D でアンカーが効かないためコードで設定）。
	# CenterContainer が中の 480x360 の箱を正しく中央に配置する。
	center_container.position = Vector2.ZERO
	center_container.size = get_viewport_rect().size

func reset_room() -> void:
	player.reset()
	player.set_process_to(false)
	player.anim_dir = "right"
	player.set_sprite(Vector2.ZERO)
	Camera.set_node_data($CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/Camera, $CenterContainer/EffectLayer/SubViewportContainer, $CenterContainer/EffectLayer/SubViewportContainer/SubViewport)
	Camera.reset_target_dictionary()
	Camera.add_target("player", player)
	Camera.add_target("hakubo", hakubo)
	Camera.set_state(Camera.CameraState.AVERAGE_CENTER)
	Camera.map_rect = Rect2(Vector2.ZERO, Vector2(1200, 1450))
	Dialogue.reset_speakers()
	Dialogue.add_speaker("player", player)
	Dialogue.add_speaker("hakubo", hakubo)
	Dialogue.load_ending_json()
	Effects.set_can_shake_decay(true)
	Effects.shake(0.0)

	player.global_position = player_spawn.global_position
	Camera.activate_brief_camera()
	Dialogue.play_conversation("ending")
	
	ui_layer.set_title_screen_time("黎明")
	ui_layer.show_title_screen()
