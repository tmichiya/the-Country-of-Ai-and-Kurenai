extends Node2D
signal attack_finished

@onready var hit_box: Area2D = $Hitbox
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player: CharacterBody2D = get_parent() as CharacterBody2D
@export var damage: float = 20.0

var _attack_direction: Vector2 = Vector2.ZERO

func enable_hitbox() -> void:
	if slash_attack_count == 0:
		hit_box.get_node("FirstAndSecondAttackCollision").set_deferred("disabled", false)
	elif slash_attack_count == 1:
		hit_box.get_node("FirstAndSecondAttackCollision").set_deferred("disabled", false)
	elif slash_attack_count >= 2:
		hit_box.get_node("ThirdAttackCollision").set_deferred("disabled", false)

func disable_hitbox() -> void:
	if slash_attack_count == 0:
		hit_box.get_node("FirstAndSecondAttackCollision").set_deferred("disabled", true)
	elif slash_attack_count == 1:
		hit_box.get_node("FirstAndSecondAttackCollision").set_deferred("disabled", true)
	elif slash_attack_count >= 2:
		hit_box.get_node("ThirdAttackCollision").set_deferred("disabled", true)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy"):
		return

	var enemy = area.get_parent() as CharacterBody2D

	if enemy.mana_component.has_method("take_damage"):
		enemy.mana_component.take_damage(damage, ManaComponent.Reason.TAKE_DAMAGE)
		enemy.play_damage_animation()
		print("Dealt ", damage, " damage to enemy. Enemy mana is now: ", enemy.mana_component.get_mana())
		if enemy.has_method("is_telegraphing") and enemy.is_telegraphing() and enemy.has_method("force_attack_to_finish"):
			enemy.force_attack_to_finish()
	
	hit_box.set_deferred("monitoring", false)

func do_paint() -> void:
	if slash_attack_count == 0:
		get_parent().get_parent().get_node("PaintLayer").paint_fan(get_parent().global_position, _attack_direction.angle(), deg_to_rad(90), 50, 2)
		AudioManager.play_se("swing_light")
	elif slash_attack_count == 1:
		get_parent().get_parent().get_node("PaintLayer").paint_fan(get_parent().global_position, _attack_direction.angle(), deg_to_rad(90), 50, 2)
		AudioManager.play_se("swing_light")
	elif slash_attack_count >= 2:
		get_parent().get_parent().get_node("PaintLayer").paint_blob(get_parent().global_position, 70, 2)
		AudioManager.play_se("swing_heavy")

	# AudioManager.play_se("slash")
	AudioManager.play_se("ink_splash_small")

func do_dash() -> void:
	if slash_attack_count == 0:
		player.dash(0.03, _attack_direction)
	elif slash_attack_count == 1:
		player.dash(0.03, _attack_direction)
	elif slash_attack_count >= 2:
		player.dash(0.05, _attack_direction)

func _on_animation_finished(anim_name: String) -> void:
	attack_finished.emit()
	queue_free()

var slash_attack_count = 0
func _ready() -> void:
	if not player:
		push_error("Player node not found in parent.")
		return
	
	if GameManager.easy_mode:
		damage = 33.0
	else:
		damage = 20.0
	
	slash_attack_count = player.get_slash_attack_count()
	print("[slash] count = ", slash_attack_count)  # 追加
	if slash_attack_count == 0:
		animation_player.play("attack_slash_first")
		damage *= 0.80
	elif slash_attack_count == 1:
		animation_player.play("attack_slash_second")
		damage *= 0.80
	elif slash_attack_count >= 2:
		animation_player.play("attack_slash_third")

	animation_player.animation_finished.connect(_on_animation_finished)
	
	_attack_direction = player.calc_attack_direction()

	rotation = _attack_direction.angle()

	hit_box.area_entered.connect(_on_hitbox_area_entered)
