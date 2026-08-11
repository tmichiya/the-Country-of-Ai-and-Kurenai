extends Node2D
signal attack_finished
signal parried(position: Vector2)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_box: Area2D = $HitBox
@export var damage: int = 20

var is_telegraphing: bool = false

func enable_hitbox() -> void:
	hit_box.get_node("CollisionPolygon2D").set_deferred("disabled", false)

func disable_hitbox() -> void:
	hit_box.get_node("CollisionPolygon2D").set_deferred("disabled", true)

func is_playing_telegraph_animation() -> bool:
	return is_telegraphing

func switch_is_telegraphing_to(value: bool) -> void:
	is_telegraphing = value

func _on_hitbox_area_entered(area: Area2D) -> void:
	print("Attack hitbox area entered by: %s" % area.name)
	if area.is_in_group("player"):
		var player = area.get_parent() as CharacterBody2D
		if player.has_method("take_damage"):
			player.take_damage(damage)

	if area.is_in_group("parry"):
		parried.emit(area.global_position)
		attack_finished.emit()
		queue_free()
		return

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_onagi":
		print("Attack Onagi animation finished")
		attack_finished.emit()
		queue_free()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.play("attack_onagi")
	animation_player.animation_finished.connect(_on_animation_finished)

	hit_box.area_entered.connect(_on_hitbox_area_entered)
