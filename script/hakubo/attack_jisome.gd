extends HakuboAttack

@export var radius : float = 95.0

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_jisome":
		finish_attack()

func do_paint() -> void:
	if paint_layer:
		var world_pos = get_parent().global_position
		paint_layer.paint_blob(world_pos, radius, 3, Vector2.ZERO)
		for i in range(15):
			var new_radius = radius * randf_range(0.1, 0.3)
			var offset = Vector2.from_angle(rad_to_deg(randf() * 360)) * radius * randf_range(1.0, 1.5)
			paint_layer.paint_blob(world_pos + offset, new_radius, 3, Vector2.ZERO)
			await get_tree().create_timer(randf_range(0.03, 0.05), true, false, true).timeout

		AudioManager.play_se("ink_splash_large")

func _ready() -> void:
	super()
	animation_player.play("attack_jisome")
	if animation_rig:
		animation_rig.play_attack_animation("attack_jisome", self)
	global_rotation = 0.0

