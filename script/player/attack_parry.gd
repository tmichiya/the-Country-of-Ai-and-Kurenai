extends Node2D
signal attack_finished
signal parried

@onready var hit_box: Area2D = $Hitbox
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player : CharacterBody2D = get_parent() as CharacterBody2D
@export var damage: int = 5

# 1回のパリィ入力で成立させられるのは1発だけ。
var is_consumed: bool = false

func try_consume() -> bool:
	if is_consumed:
		return false
	is_consumed = true
	_finish()
	return true

func _finish() -> void:
	# remove_from_group は即時反映されるので、同フレームの後続判定もここで弾ける
	if hit_box.is_in_group("parry"):
		hit_box.remove_from_group("parry")
	hit_box.set_deferred("monitoring", false)
	hit_box.set_deferred("monitorable", false)

	AudioManager.play_se("parry")

	player.mana_component.restore(70.0) # パリィ成功時にマナを回復する

	player.set_hurtbox_monitor(true)
	parried.emit()
	attack_finished.emit()
	queue_free()

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_parry":
		player.set_hurtbox_monitor(true)
		attack_finished.emit()
		queue_free()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hakubo_attack"):
		return

func _ready() -> void:
	animation_player.play("attack_parry")
	animation_player.animation_finished.connect(_on_animation_finished)

	hit_box.area_entered.connect(_on_hitbox_area_entered)

	player.set_hurtbox_monitor(false) # パリィ中はプレイヤーの当たり判定を無効化する

	AudioManager.play_se("parry_attack")
