extends HakuboAttack

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_super_hyper_jisome":
		finish_attack()

func do_paint() -> void:
	if paint_layer:
		var world_pos = get_parent().global_position

		global_rotation = (get_parent().get_player_position() - get_parent().global_position).normalized().angle()
		paint_layer.paint_fan(world_pos, global_rotation, deg_to_rad(100), 120, 3)

		AudioManager.play_se("ink_splash_large")

func _ready() -> void:
	super()
	animation_player.play("attack_super_hyper_jisome")
	global_rotation = 0.0

	var hakubo = get_parent() as CharacterBody2D
	if hakubo:
		var distance_to_player = hakubo.get_player_distance()
		var player_vector = hakubo.get_player_vector()
		var expected_direction = ((hakubo.get_player_position() + player_vector * 60) - hakubo.global_position).normalized().angle()
		hakubo.set_direction(expected_direction)
		rotation = expected_direction
		hakubo.dash(0.5, distance_to_player * 7.0)

	# set_direction で向き直った後の方向を渡す
	if animation_rig:
		animation_rig.play_attack_animation("attack_super_hyper_jisome", self)

