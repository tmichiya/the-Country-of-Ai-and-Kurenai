extends HakuboAttack

var animation_part = 0

func _hakubo_slash() -> void:
	if animation_rig:
			animation_rig.play_attack_animation("attack_sandankuzushi", self, Vector2.from_angle(hakubo.direction))

func _action_ready() -> void:
	if hakubo:
		var player_position = hakubo.get_player_position()
		var new_direction = (player_position - hakubo.global_position).normalized().angle()
		var distance_to_player = hakubo.get_player_distance()
		rotation = new_direction
		hakubo.set_direction(new_direction)
		hakubo.dash(0.5, distance_to_player * 10.0)


func _on_animation_finished(anim_name: String) -> void:
	await get_tree().create_timer(0.2, false).timeout
	# 待っているあいだに攻撃が消されていたら（緊急ダッシュ・撃破・部屋の入り直し）何もしない
	if not is_instance_valid(self) or is_queued_for_deletion() or not is_inside_tree():
		return
	if anim_name == "attack_sandankuzushi_telegraphing" or anim_name == "attack_sandankuzushi_red" or anim_name == "attack_sandankuzushi_yellow":
		if animation_part == 0 or animation_part == 1 or animation_part == 2:
			animation_player.play("attack_sandankuzushi_red")
			_action_ready()
			animation_part += 1
		else:
			finish_attack()

func _on_hitbox_area_entered(area: Area2D) -> void:
	print("HitBox area entered: ", area.name)
	if area.is_in_group("parry") and can_parry and _try_consume_parry(area):
		print("Parried by: ", area.name)
		var vp = get_viewport()
		var screen_pos = vp.get_canvas_transform() * area.global_position
		var uv = screen_pos / vp.get_visible_rect().size    # 0〜1 に正規化
		parried.emit(uv)
		# この攻撃では parry で止まらない。スタン後に三段攻撃の次の段から再開する。
		# ここでは await しない（await すると、0.5 秒後に消えた area を触ってしまう）
		_stun_then_resume()
		return

	if area.is_in_group("player"):
		print("Player hit by: ", area.name)
		var player = area.get_parent() as CharacterBody2D
		player.take_damage(damage, ManaComponent.Reason.TAKE_DAMAGE)

		_stun_then_resume()

@export var parry_stun_time: float = 0.2
var _is_stunned: bool = false

## パリィされたら少しスタンして、三段の「次の段」から再開する。
func _stun_then_resume() -> void:
	if _is_stunned:
		return
	_is_stunned = true
	can_parry = false
	disable_hitbox()   # stop() で disable_hitbox のキーが流れないので、ここで消す
	var resume_anim: StringName = animation_player.current_animation   # stop() の前に覚える
	animation_player.stop()
	hakubo.dash(0.6, 900.0 * -1.0)
	animation_rig.play_attack_animation("attack_super_hyper_sandankuzushi_parried", self, Vector2.from_angle(hakubo.direction))

	await get_tree().create_timer(parry_stun_time, false).timeout
	# 待っているあいだに攻撃が消されていたら（緊急ダッシュ・撃破・部屋の入り直し）何もしない
	if not is_instance_valid(self) or is_queued_for_deletion() or not is_inside_tree():
		return

	_is_stunned = false
	_on_animation_finished(resume_anim)   # 覚えておいたアニメ名で次の段へ進める

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
