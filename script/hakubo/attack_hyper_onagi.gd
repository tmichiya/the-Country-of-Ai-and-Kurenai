extends HakuboAttack

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_hyper_onagi":
		finish_attack()

func _hakubo_slash() -> void:
	var hakubo = get_parent() as CharacterBody2D
	if hakubo:
		var distance_to_player = hakubo.get_player_distance()
		rotation = hakubo.direction
		hakubo.dash(0.5, distance_to_player * 6.0)
		hakubo.jump(50.0, 0.5)

func do_paint() -> void:
	if paint_layer:
		paint_layer.paint_fan(get_parent().global_position, get_parent().direction, deg_to_rad(110), 60, 3)

		AudioManager.play_se("slash")
		AudioManager.play_se("ink_splash_small")

func _ready() -> void:
	super()
	rotation = get_parent().direction
	animation_player.play("attack_hyper_onagi")
	if animation_rig:
		animation_rig.play_attack_animation("attack_hyper_onagi", self, Vector2.from_angle(hakubo.direction))

	var hakubo = get_parent() as CharacterBody2D
	if hakubo:
		var distance_to_player = hakubo.get_player_distance()
		hakubo.dash(0.5, distance_to_player * 5.0)

