extends Node2D

@export var player: CharacterBody2D
@export var akane: CharacterBody2D

@onready var ui_manager: CanvasLayer = $UILayer
@onready var result_screen = $UILayer/ResultScreen

var battle_active: bool = true

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

	player.set_process_input(false)
	player.set_physics_process(false)
	akane.set_physics_process(false)

	var color := Effects.FLASH_AI if is_win else Effects.FLASH_KURENAI
	var target: Node2D = akane if is_win else player
	var uv := _world_to_uv(target)

	Effects.slowmotion(0.15, 1.2)
	Effects.shake(20.0)
	Effects.flash_impact(color, 1.0, 0.5, uv)
	await get_tree().create_timer(1.5, true, false, true).timeout
	show_result(is_win)
	_proceed_after_result(is_win)

func _proceed_after_result(is_win: bool) -> void:
	if is_win:
		# 勝利の余韻を少し置いてから、自動で焚火へ
		await get_tree().create_timer(2.0, true, false, true).timeout
		GameManager.go_to_campfire()
	else:
		# 敗北時はその場でやり直し（周回は進めない）
		await GameManager.wait_for_confirm()
		GameManager.retry_boss()

func _on_player_mana_changed(current_mana: float, max_mana: float) -> void:
	ui_manager.set_player_mana(current_mana, max_mana)

func _on_akane_mana_changed(current_mana: float, max_mana: float) -> void:
	ui_manager.set_akane_mana(current_mana, max_mana)

func show_result(is_win: bool) -> void:
	result_screen.visible = true
	var result_label = result_screen.get_node("ResultLabel") as Label
	if is_win:
		result_label.text = "制圧"
	else:
		result_label.text = "染没"

func setup_ui() -> void:
	ui_manager.set_player_mana(player.mana_component.mana, player.mana_component.max_mana)
	ui_manager.set_akane_mana(akane.mana_component.mana, akane.mana_component.max_mana)

	result_screen.visible = false

func _ready() -> void:
	player.mana_component.depleted.connect(_on_player_died)
	player.mana_component.mana_changed.connect(_on_player_mana_changed)
	akane.mana_component.depleted.connect(_on_akane_died)
	akane.mana_component.mana_changed.connect(_on_akane_mana_changed)

	setup_ui()
