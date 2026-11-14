extends HakuboAttack

var animation_part = 0

## red / yellow のメソッドトラックから呼ぶ。体と武器の斬りのアニメを流す。
func _hakubo_slash() -> void:
	if animation_rig:
			animation_rig.play_attack_animation("attack_sandankuzushi", self, Vector2.from_angle(hakubo.direction))

## 次の段に入る直前に、プレイヤーの方を向いて踏み込む。
func _action_ready() -> void:
	if hakubo:
		var player_position = hakubo.get_player_position()
		var new_direction = (player_position - hakubo.global_position).normalized().angle()
		var distance_to_player = hakubo.get_player_distance()
		rotation = new_direction
		hakubo.set_direction(new_direction)

		if animation_part == 0 or animation_part == 1:
			hakubo.dash(0.5, distance_to_player * 2.0)
		elif animation_part == 2:
			hakubo.dash(0.5, distance_to_player * 9.0)


func _on_animation_finished(anim_name: String) -> void:
	await get_tree().physics_frame
	if is_queued_for_deletion():
		return
	if anim_name == "attack_sandankuzushi_telegraphing" or anim_name == "attack_sandankuzushi_red" or anim_name == "attack_sandankuzushi_yellow":
		if animation_part == 0 or animation_part == 1:
			animation_player.play("attack_sandankuzushi_yellow")
			_action_ready()
			animation_part += 1
		elif animation_part == 2:
			animation_player.play("attack_sandankuzushi_red")
			_action_ready()
			animation_part += 1
		else:
			finish_attack()

func do_paint() -> void:
	if paint_layer:
		paint_layer.paint_fan(get_parent().global_position, get_parent().direction, deg_to_rad(110), 70, 3)

		AudioManager.play_se("slash")
		AudioManager.play_se("ink_splash_small")

func _ready() -> void:
	super()
	animation_part = 0
	animation_player.play("attack_sandankuzushi_telegraphing")

	if animation_rig:
		animation_rig.play_attack_animation("attack_sandankuzushi_telegraphing", self, Vector2.from_angle(hakubo.direction))
