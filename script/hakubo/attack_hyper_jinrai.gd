extends HakuboAttack

var jinrai_count: int = 0
var jinrai_max_count: int = 0

func _hakubo_slash() -> void:
	if not hakubo:
		hakubo = get_parent() as CharacterBody2D
	if hakubo:
		var distance_to_player = hakubo.get_player_distance()
		var player_vector = hakubo.get_player_vector()
		var expected_direction = ((hakubo.get_player_position() + player_vector * 60) - hakubo.global_position).normalized().angle()
		hakubo.set_direction(expected_direction)
		rotation = expected_direction
		# 狙い直した方向に武器も向ける
		if animation_rig:
			animation_rig.update_attack_direction(Vector2.from_angle(expected_direction))
		hakubo.dash(0.5, distance_to_player * 9.0)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_hyper_jinrai":
		if jinrai_count < jinrai_max_count:
			jinrai_count += 1
			# 一回撤退してから
			var retreat_direction = hakubo.ai_controller.calc_retreat_direction(false)
			hakubo.dash(0.6, 300.0, retreat_direction)
			hakubo.jump(45, 0.6)
			animation_player.play("attack_hyper_jinrai")
		else:
			finish_attack()

func do_paint() -> void:
	if paint_layer:
		paint_layer.paint_fan(get_parent().global_position, get_parent().direction, deg_to_rad(110), 70, 3)

		AudioManager.play_se("slash")
		AudioManager.play_se("ink_splash_small")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	jinrai_count = 0

	var loop_count = GameManager.get_loop_count()
	if loop_count == 2:
		jinrai_max_count = 3
	elif loop_count == 1:
		jinrai_max_count = 2
	else:
		jinrai_max_count = 1

	hakubo = get_parent() as CharacterBody2D

	animation_player.play("attack_hyper_jinrai")
	if animation_rig:
		animation_rig.play_attack_animation("attack_hyper_jinrai", self, Vector2.from_angle(hakubo.direction))

func _process(delta: float) -> void:
	if is_playing_telegraph_animation():
		if hakubo :
			rotation = hakubo.direction			

