extends HakuboAttack

var animation_part = 0

func _hakubo_slash() -> void:
	var hakubo = get_parent() as CharacterBody2D
	if hakubo:
		var distance_to_player = hakubo.get_player_distance()
		var player_position = hakubo.get_player_position()
		rotation = (player_position - hakubo.global_position).normalized().angle()
		hakubo.set_direction(rotation)
		hakubo.dash(0.5, distance_to_player * 7.0)

func _on_animation_finished(_anim_name: String) -> void:
	await get_tree().physics_frame
	if is_queued_for_deletion():
		return
	animation_part += 1
	match animation_part:
		1, 2:
			animation_player.play("attack_sandankuzushi_red")
		3:
			animation_player.play("attack_sandankuzushi_yellow")
		_:
			finish_attack()

func _play_body_animation() -> void:
	if animation_rig:
		animation_rig.play_attack_animation(&"attack_sandankuzushi", self, Vector2.from_angle(hakubo.direction))

func do_paint() -> void:
	if paint_layer:
		paint_layer.paint_fan(get_parent().global_position, get_parent().direction, deg_to_rad(110), 30, 3)

		AudioManager.play_se("slash")
		AudioManager.play_se("ink_splash_small")

func _ready() -> void:
	super()
	animation_part = 0

	animation_player.play("attack_sandankuzushi_telegraphing")
	_play_body_animation()

