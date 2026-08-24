extends Node2D

signal battle_started
signal battle_finished(is_win: bool)

@export var boss_stage: Node2D

@export var player: CharacterBody2D
@export var akane: CharacterBody2D
@export var paint_layer: Node2D

@onready var ui_manager: CanvasLayer = $UILayer
@onready var result_screen = $UILayer/CenterContainer/ResultScreen
@onready var result_anim = $UILayer/CenterContainer/ResultScreen/AnimationPlayer

var battle_active: bool = true
var player_start_position: Vector2
var akane_start_position: Vector2

func reset_battle() -> void:
	battle_active = false
	player.global_position = player_start_position
	akane.global_position = akane_start_position
	player.reset()
	akane.reset()
	paint_layer.reset()
	setup_ui()

func _on_player_died() -> void:
	print("Player has died.")
	_end_battle(false)

func _on_akane_died() -> void:
	print("Akane has died.")
	_end_battle(true)

func _world_to_uv(node: Node2D) -> Vector2:
	var vp := node.get_viewport()
	var screen_pos := vp.get_canvas_transform() * node.global_position
	return screen_pos / vp.get_visible_rect().size

func _end_battle(is_win: bool) -> void:
	if not battle_active:
		return
	battle_active = false

	player.set_process_to(false)
	akane.set_process_to(false)
	akane.state = akane.State.IDLE
	paint_layer.set_physics_process(false)

	var color : Color = Effects.FLASH_AI if is_win else Effects.FLASH_KURENAI
	var target: Node2D = akane if is_win else player
	var uv := _world_to_uv(target)

	Effects.slowmotion(0.15, 1.2)
	Effects.shake(20.0)
	Effects.flash_impact(color, 1.0, 0.5, uv)
	await get_tree().create_timer(1.5, true, false, true).timeout
	show_result(is_win)
	battle_finished.emit(is_win)

func _start_battle() -> void:
	battle_active = true
	battle_started.emit()

	Camera.set_state(Camera.CameraState.AVERAGE_CENTER)

func _on_player_mana_changed(current_mana: float, max_mana: float) -> void:
	ui_manager.set_player_mana(current_mana, max_mana)

func _on_akane_mana_changed(current_mana: float, max_mana: float) -> void:
	ui_manager.set_akane_mana(current_mana, max_mana)

func show_result(is_win: bool) -> void:
	result_screen.visible = true
	var result_label = result_screen.get_node("Control").get_node("ResultLabel") as Label
	if is_win:
		result_label.text = "制圧"
	else:
		result_label.text = "染没"
	result_anim.play("result_screen_show")

func _on_result_animation_finished(anim_name: String) -> void:
	if anim_name == "result_screen_show":
		player.set_process_to(true)

func setup_ui() -> void:
	ui_manager.set_player_mana(player.mana_component.mana, player.mana_component.max_mana)
	ui_manager.set_akane_mana(akane.mana_component.mana, akane.mana_component.max_mana)

	result_screen.visible = false

func _ready() -> void:
	var player_start_marker = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/PlayerStartMarker as Marker2D
	var akane_start_marker = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/AkaneStartMarker as Marker2D

	if not player_start_marker or not akane_start_marker:
		push_error("PlayerStartMarker or AkaneStartMarker is missing in the scene.")
	else:
		player_start_position = player_start_marker.global_position
		akane_start_position = akane_start_marker.global_position

	boss_stage.battle_started.connect(_start_battle)
	player.mana_component.depleted.connect(_on_player_died)
	player.mana_component.mana_changed.connect(_on_player_mana_changed)
	akane.mana_component.depleted.connect(_on_akane_died)
	akane.mana_component.mana_changed.connect(_on_akane_mana_changed)
	result_anim.animation_finished.connect(_on_result_animation_finished)

	setup_ui()
