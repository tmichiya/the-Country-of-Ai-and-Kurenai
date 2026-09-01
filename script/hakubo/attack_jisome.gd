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
		var world_pos = get_parent().global_position
		paint_layer.paint_blob(world_pos, radius, 3, Vector2.ZERO)
		for i in range(15):
			var new_radius = radius * randf_range(0.1, 0.3)
			var offset = Vector2.from_angle(rad_to_deg(randf() * 360)) * radius * randf_range(1.0, 1.5)
			paint_layer.paint_blob(world_pos + offset, new_radius, 3, Vector2.ZERO)
			await get_tree().create_timer(randf_range(0.03, 0.05), true, false, true).timeout

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.play("attack_jisome")
	animation_player.animation_finished.connect(_on_animation_finished)
	global_rotation = 0.0

	hit_box.area_entered.connect(_on_hitbox_area_entered)
