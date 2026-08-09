extends Node2D
signal attack_finished

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_box: Area2D = $HitBox
@export var damage: int = 10

var is_telegraphing: bool = false

func enable_hitbox() -> void:
	hit_box.get_node("CollisionShape2D").set_deferred("disabled", false)

func disable_hitbox() -> void:
	hit_box.get_node("CollisionShape2D").set_deferred("disabled", true)

func is_playing_telegraph_animation() -> bool:
	return animation_player.is_playing() == false

func switch_is_telegraphing_to(value: bool) -> void:
	is_telegraphing = value

func _on_hitbox_area_entered(area: Area2D) -> void:
	print("Hitbox area entered: %s" % area.name)
	print("Area groups: %s" % area.get_groups())
	if not area.is_in_group("player"):
		return
	print("Hit player: %s" % area.name)

	var player = area.get_parent() as CharacterBody2D
	if player.has_method("take_damage"):
		player.take_damage(damage)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_karatake":
		print("Attack Karatake animation finished")
		attack_finished.emit()
		queue_free()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hit_box.area_entered.connect(_on_hitbox_area_entered)
