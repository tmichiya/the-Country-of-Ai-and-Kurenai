extends Node2D
signal attack_finished

@onready var hit_box: Area2D = $Hitbox
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@export var damage: int = 10

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy"):
		return

	var enemy = area.get_parent() as CharacterBody2D

	if enemy.mana_component.has_method("take_damage"):
		if enemy.has_method("is_telegraphing") and enemy.is_telegraphing():
			enemy.mana_component.take_damage(damage * 2)
			return
		enemy.mana_component.take_damage(damage)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_parry":
		attack_finished.emit()
		queue_free()

func _ready() -> void:
	# rotation = global_position.angle_to_point(get_global_mouse_position())
	animation_player.play("attack_parry")
	animation_player.animation_finished.connect(_on_animation_finished)

	

	hit_box.area_entered.connect(_on_hitbox_area_entered)
