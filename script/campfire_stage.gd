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

var player_in_bonfire_range := false

func _ready() -> void:
	campfire.body_entered.connect(_on_bonfire_entered)
	campfire.body_exited.connect(_on_bonfire_exited)
	warp_area.body_entered.connect(_on_warp_entered)

func reset_room() -> void:
	player.reset()
	player_in_bonfire_range = false
	prompt_label.visible = false
	skill_panel.visible = false

func _on_bonfire_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	player_in_bonfire_range = true
	prompt_label.visible = true

func _on_bonfire_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	player_in_bonfire_range = false
	prompt_label.visible = false
	skill_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_bonfire_range and event.is_action_pressed("ui_accept"):
		skill_panel.visible = not skill_panel.visible

func _on_warp_entered(body: Node) -> void:
	if not body.is_in_group("player") or skill_panel.visible:
		return
	GameManager.advance_loop_and_fight()
