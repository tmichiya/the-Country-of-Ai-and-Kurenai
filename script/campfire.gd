extends Node2D

@onready var interaction_area: Node2D = $InteractionArea
@onready var animated_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@export var interaction_text: Label
var text_animation_player: AnimationPlayer


var is_saving: bool = false

func _ready() -> void:
	interaction_area.interaction_started.connect(_on_interaction_started)
	interaction_area.interaction_ended.connect(_on_interaction_ended)
	interaction_area.interacted.connect(_on_interacted)
	SaveManager.save_started.connect(_on_save_started)
	SaveManager.save_finished.connect(_on_save_finished)

	text_animation_player = interaction_text.get_node("AnimationPlayer") as AnimationPlayer

	interaction_text.visible = false

func _on_interaction_started() -> void:
	if is_saving:
		return

	animated_sprite.play("selected")
	interaction_text.visible = true
	interaction_text.text = "焚火を選択してセーブ..."
	text_animation_player.play("fade_in")

func _on_interaction_ended() -> void:
	animated_sprite.play("unselected")
	if not is_saving:
		interaction_text.visible = false

func _on_save_started() -> void:
	animated_sprite.play("unselected")
	is_saving = true
	interaction_text.visible = true
	text_animation_player.play("fade_in")
	interaction_text.text = "セーブ中..."

func _on_save_finished() -> void:
	interaction_text.visible = true
	interaction_text.text = "セーブ完了！"

	await get_tree().create_timer(0.2).timeout
	text_animation_player.play("fade_out")
	await get_tree().create_timer(0.1).timeout

	interaction_text.visible = false
	is_saving = false

func _on_interacted() -> void:
	if is_saving:
		return

	GameManager.save_game()