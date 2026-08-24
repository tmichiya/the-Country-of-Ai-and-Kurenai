extends Node2D
## 焚火ステージ（歩けるルーム版）。
## ・焚火に近づく → 決定キーでスキル画面（仮）の開閉
## ・奥の地点（WarpArea）に到達 → 次のボス戦へ（GameManager 経由）

@export var player: CharacterBody2D
@export var player_spawn: Marker2D
@export var campfire: Node2D
@export var warp_area: Node2D

@onready var skill_panel: Control = $UILayer/SkillPanel
@onready var prompt_label: Label = $UILayer/PromptLabel
@onready var ui_layer: CanvasLayer = $UILayer
@onready var camera: Camera2D = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/Camera

var player_in_bonfire_range := false

func _ready() -> void:
	campfire.entered.connect(_on_bonfire_entered)
	campfire.exited.connect(_on_bonfire_exited)
	warp_area.entered.connect(_on_warp_entered)

func set_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	ui_layer.visible = active
	camera.enabled = active

func reset_room() -> void:
	player.reset()
	player_in_bonfire_range = false
	prompt_label.visible = false
	skill_panel.visible = false
	Camera.set_node_data($CenterContainer/EffectLayer/SubViewportContainer/SubViewport/Camera, $CenterContainer/EffectLayer/SubViewportContainer, $CenterContainer/EffectLayer/SubViewportContainer/SubViewport)
	Camera.reset_target_dictionary()
	Camera.add_target("player", player)
	Camera.set_state(Camera.CameraState.FOLLOW_TARGET)
	Camera.set_current_target("player")
	Dialogue.reset_speakers()
	Dialogue.add_speaker("player", player)

func _on_bonfire_entered() -> void:
	player_in_bonfire_range = true
	prompt_label.visible = true

func _on_bonfire_exited() -> void:
	player_in_bonfire_range = false
	prompt_label.visible = false
	skill_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_bonfire_range and event.is_action_pressed("ui_accept"):
		skill_panel.visible = not skill_panel.visible

func _on_warp_entered() -> void:
	GameManager.advance_loop_and_fight()
