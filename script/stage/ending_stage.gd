extends Node2D

@export var player: CharacterBody2D
@export var hakubo: Sprite2D
@export var player_spawn: Marker2D

@onready var ui_layer: CanvasLayer = $UILayer
@onready var camera: Camera2D = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/Camera

@onready var center_container: CenterContainer = $CenterContainer

func _ready() -> void:
	Dialogue.finished.connect(_on_dialogue_finished)
	UnityroomManager.send_clear_time(GameManager.get_total_time())

	get_viewport().size_changed.connect(_fit_center_container)
	_fit_center_container()

	await get_tree().create_timer(1.0).timeout

	reset_room()

var bird_se_timer := 0.0
var bird_se_interval := 1.0
func _process(delta: float) -> void:
	bird_se_timer += delta
	if bird_se_timer >= bird_se_interval:
		bird_se_timer = 0.0
		bird_se_interval = randf_range(6.0, 10.0)
		AudioManager.play_random_bird_se()

func _on_dialogue_finished(tag: String) -> void:
	if tag == "ending":
		Camera.start_ending_logo_animation()

func start_ending_dialogue() -> void:
	await Dialogue.play_conversation("ending")
	Camera.start_ending_logo_animation()
	player.set_process_to(false)

func change_scene_to_result_score() -> void:
	GameManager.go_to_result_score()

func _fit_center_container() -> void:
	center_container.position = Vector2.ZERO
	center_container.size = get_viewport_rect().size

func reset_room() -> void:
	player.reset()
	player.set_process_to(false)
	player.anim_dir = "right"
	player.set_sprite(Vector2.ZERO)
	Camera.set_node_data($CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/Camera, $CenterContainer/EffectLayer/SubViewportContainer, $CenterContainer/EffectLayer/SubViewportContainer/SubViewport)
	Camera.reset_target_dictionary()
	Camera.set_state(Camera.CameraState.FREE)
	Camera.map_rect = Rect2(Vector2.ZERO, Vector2(1200, 1450))
	Dialogue.reset_speakers()
	Dialogue.add_speaker("player", player)
	Dialogue.add_speaker("hakubo", hakubo)
	Dialogue.load_ending_json()
	Effects.set_can_shake_decay(true)
	Effects.shake(0.0)

	player.global_position = player_spawn.global_position
	Camera.activate_brief_camera()

	Camera.start_ending_animation()
	
	ui_layer.set_title_screen_time("黎明")
	ui_layer.show_title_screen()

	AudioManager.play_bgm(AudioManager.BGM_ENDING_STAGE, 0.5, true)
