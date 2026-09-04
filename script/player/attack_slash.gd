extends Node2D
signal attack_finished

@onready var hit_box: Area2D = $Hitbox
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player: CharacterBody2D = get_parent() as CharacterBody2D
@export var damage: int = 15

func enable_hitbox() -> void:
	hit_box.get_node("CollisionPolygon2D").set_deferred("disabled", false)

func disable_hitbox() -> void:
	hit_box.get_node("CollisionPolygon2D").set_deferred("disabled", true)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy"):
		return

	var enemy = area.get_parent() as CharacterBody2D

	if enemy.mana_component.has_method("take_damage"):
		# if enemy.has_method("is_telegraphing") and enemy.is_telegraphing():
		# 	enemy.mana_component.take_damage(damage * 1.3)
		# 	return

		# debug
		# if enemy.mana_component.get_mana() < damage:
		# 	return
		enemy.mana_component.take_damage(damage)
		enemy.animation_player.play("damage")
		print("Dealt ", damage, " damage to enemy. Enemy mana is now: ", enemy.mana_component.get_mana())
		if enemy.has_method("is_telegraphing") and enemy.is_telegraphing() and enemy.has_method("force_attack_to_finish"):
			enemy.force_attack_to_finish()
	
	hit_box.set_deferred("monitoring", false)

func do_paint() -> void:
	get_parent().get_parent().get_node("PaintLayer").paint_fan(get_parent().global_position, get_parent().get_direction(), deg_to_rad(110), 50, 2)

	AudioManager.play_se("slash")
	AudioManager.play_se("ink_splash_small")

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_slash":
		attack_finished.emit()
		queue_free()

func _ready() -> void:
	animation_player.play("attack_slash")
	animation_player.animation_finished.connect(_on_animation_finished)
	rotation = player.get_direction()

	hit_box.area_entered.connect(_on_hitbox_area_entered)
