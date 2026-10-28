extends Node2D
signal attack_finished
signal parried

@onready var hit_box: Area2D = $Hitbox
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player : CharacterBody2D = get_parent() as CharacterBody2D
## 持ち主（player）が add_child の前に渡す。単体テスト時などは null のままでも動く。
var animation_rig: AttackAnimationRig
@export var damage: float = 5

# 1回のパリィ入力で成立させられるのは1発だけ。
var is_consumed: bool = false
## 終了処理（成功・時間切れ）を一度でも通ったか。二重に終わらせないためのガード。
var _ended: bool = false

## 万一アニメの終了通知が来なくても、パリィが居残って次のパリィを塞がないための上限（秒）。
const MAX_LIFETIME := 1.0
var _lifetime: float = 0.0

func try_consume() -> bool:
	if is_consumed:
		return false
	_finish()
	return true

## パリィ成功時の終了処理。
func _finish() -> void:
	if _ended:
		return
	_ended = true
	is_consumed = true
	# remove_from_group は即時反映されるので、同フレームの後続判定もここで弾ける
	if hit_box.is_in_group("parry"):
		hit_box.remove_from_group("parry")
	_set_hitbox_active(false)

	AudioManager.play_se("parry")

	player.mana_component.restore(70.0, ManaComponent.Reason.PARRY) # パリィ成功時にマナを回復する

	player.set_hurtbox_monitor(true)
	parried.emit()
	attack_finished.emit()
	queue_free()

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_parry":
		_end_without_success()

## 何も弾けずに終わったときの終了処理（アニメ終了・時間切れ）。
func _end_without_success() -> void:
	if _ended:
		return
	_ended = true
	_set_hitbox_active(false)
	player.set_hurtbox_monitor(true)
	attack_finished.emit()
	queue_free()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hakubo_attack"):
		return

func _set_hitbox_active(active: bool) -> void:
	hit_box.set_deferred("monitoring", active)
	hit_box.set_deferred("monitorable", active)

func _ready() -> void:
	if animation_rig:
		animation_rig.play_attack_animation("attack_parry", self)

	animation_player.play("attack_parry")
	animation_player.animation_finished.connect(_on_animation_finished)

	hit_box.area_entered.connect(_on_hitbox_area_entered)

	player.set_hurtbox_monitor(false) # パリィ中はプレイヤーの当たり判定を無効化する
	# 「パリィ中か」は player 側が parry_instance の有無で判断するので、ここでは何も立てない

	AudioManager.play_se("parry_attack")

func _exit_tree() -> void:
	if is_queued_for_deletion():
		player.set_hurtbox_monitor(true) # パリィが終了したらプレイヤーの当たり判定を有効化する

func _process(delta: float) -> void:
	if _ended:
		return
	# 仮にhakuboの攻撃が終了した後でも、パリィが可能になるようにする
	if player.is_damaged:
		_finish()
		return

	_lifetime += delta
	if _lifetime >= MAX_LIFETIME:
		push_warning("AttackParry: アニメ終了の通知が来ないまま %.1f 秒経ったので強制終了します" % MAX_LIFETIME)
		_end_without_success()
