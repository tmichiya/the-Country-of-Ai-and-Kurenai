extends Node2D
signal attack_finished

@onready var hit_box: Area2D = $Hitbox
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player: CharacterBody2D = get_parent() as CharacterBody2D
@export var damage: int = 20

var _attack_direction: Vector2 = Vector2.ZERO

func enable_hitbox() -> void:
	hit_box.get_node("CollisionPolygon2D").set_deferred("disabled", false)

func disable_hitbox() -> void:
	hit_box.get_node("CollisionPolygon2D").set_deferred("disabled", true)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy"):
		return

	var enemy = area.get_parent() as CharacterBody2D

	if enemy.mana_component.has_method("take_damage"):
		enemy.mana_component.take_damage(damage)
		enemy.play_damage_animation()
		print("Dealt ", damage, " damage to enemy. Enemy mana is now: ", enemy.mana_component.get_mana())
		if enemy.has_method("is_telegraphing") and enemy.is_telegraphing() and enemy.has_method("force_attack_to_finish"):
			enemy.force_attack_to_finish()
	
	hit_box.set_deferred("monitoring", false)

func do_paint() -> void:
	get_parent().get_parent().get_node("PaintLayer").paint_fan(get_parent().global_position, _attack_direction.angle(), deg_to_rad(110), 60, 2)

	AudioManager.play_se("slash")
	AudioManager.play_se("ink_splash_small")

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_slash":
		attack_finished.emit()
		queue_free()

func _ready() -> void:
	animation_player.play("attack_slash")
	animation_player.animation_finished.connect(_on_animation_finished)
	if player and player.target_enemy:
		if absf(player.get_facing_direction().angle_to_point(player.target_enemy.global_position)) < deg_to_rad(60):
			_attack_direction = (player.target_enemy.global_position - player.global_position)
	elif player:
		# 立ち止まっているときは、移動入力（ゼロ＝右向き）ではなく向いている方向に出す
		_attack_direction = player.get_facing_direction()
	else:
		_attack_direction = InputDevice.get_move_direction()

	rotation = _attack_direction.angle()

	hit_box.area_entered.connect(_on_hitbox_area_entered)

	if GameManager.easy_mode:
		damage = 33
	else:
		damage = 20
