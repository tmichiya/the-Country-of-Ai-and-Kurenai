extends Node2D
signal attack_finished

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_box: Area2D = $HitBox
@export var damage: int = 10

var paint_layer: Node2D = null
var is_telegraphing: bool = false

func enable_hitbox() -> void:
	hit_box.get_node("CollisionShape2D").set_deferred("disabled", false)

func disable_hitbox() -> void:
	hit_box.get_node("CollisionShape2D").set_deferred("disabled", true)

func is_playing_telegraph_animation() -> bool:
	return is_telegraphing

func switch_is_telegraphing_to(value: bool) -> void:
	is_telegraphing = value

# 以下変更の可能性あり

@export var radius : float = 95.0

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_jisome":
		attack_finished.emit()
		queue_free()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		var player = area.get_parent() as CharacterBody2D
		if player.mana_component.has_method("take_damage"):
			player.mana_component.take_damage(damage)
	
func do_paint() -> void:
	if paint_layer:
		for i in range(100):
			var random_r = randf_range(0, radius)
			var random_angle = randf_range(0, 2.0 * PI)
			var random_offset = Vector2(cos(random_angle), sin(random_angle)) * random_r
			var from = get_parent().global_position + random_offset
			var parent_rotation = get_parent().global_rotation
			var rotation : Vector2 = Vector2(cos(parent_rotation + random_angle), sin(parent_rotation + random_angle))
			paint_layer.paint_blob(from, 120 / (random_r * 0.3 + 1), 3, rotation)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.play("attack_jisome")
	animation_player.animation_finished.connect(_on_animation_finished)
	global_rotation = 0.0

	hit_box.area_entered.connect(_on_hitbox_area_entered)
