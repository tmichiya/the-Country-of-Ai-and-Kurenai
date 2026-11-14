extends HakuboAttack

func _hakubo_slash() -> void:
	if not hakubo:
		hakubo = get_parent() as CharacterBody2D
	if hakubo:
		var distance_to_player = hakubo.get_player_distance()
		var player_vector = hakubo.get_player_vector()
		var expected_direction = ((hakubo.get_player_position() + player_vector * 60) - hakubo.global_position).normalized().angle()
		hakubo.set_direction(expected_direction)
		hakubo.set_direction(expected_direction)
		rotation = expected_direction
		# 狙い直した方向に武器も向ける
		if animation_rig:
			animation_rig.update_attack_direction(Vector2.from_angle(expected_direction))
		hakubo.dash(0.5, distance_to_player * 9.0)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_jinrai":
		finish_attack()

func do_paint() -> void:
	if paint_layer:
		paint_layer.paint_fan(get_parent().global_position, get_parent().direction, deg_to_rad(110), 40, 3)

		AudioManager.play_se("slash")
		AudioManager.play_se("ink_splash_small")

func _ready() -> void:
	super()
	hakubo = get_parent() as CharacterBody2D

	animation_player.play("attack_jinrai")
	if animation_rig:
		animation_rig.play_attack_animation("attack_jinrai", self, Vector2.from_angle(hakubo.direction))

func _process(delta: float) -> void:
	if is_playing_telegraph_animation():
		if hakubo :
			rotation = hakubo.direction			

