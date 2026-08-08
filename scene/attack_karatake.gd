extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_box: Area2D = $HitBox

@export var damage: int = 10

func enable_hitbox() -> void:
	hit_box.get_node("CollisionShape2D").set_deferred("disabled", false)
	print("Hitbox enabled")

func disable_hitbox() -> void:
	hit_box.get_node("CollisionShape2D").set_deferred("disabled", true)
	print("Hitbox disabled")



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.play("attack_karatake")

	hit_box.area_entered.connect(_on_hitbox_area_entered)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_hurt"):
		return
	print("Hit player: %s" % area.name)

	var player = area.get_parent() as CharacterBody2D
	if player.has_method("take_damage"):
		player.take_damage(damage)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
