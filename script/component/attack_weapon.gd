class_name AttackWeapon
extends Node2D
## AttackAnimationRig から操作される武器。player / hakubo どちらの武器シーンのルートにも付けられる。
##
## 武器の AnimationPlayer を触るのはこのスクリプトだけ。Rig は
##   play_attack_animation() / stop_attack_animation() / set_attack_direction()
## を呼ぶだけで、武器の中身（アニメ名・RESET・向きの戻し方）は知らなくてよい。
##
## 攻撃中かどうかは is_attacking で分かる。攻撃していない間は _process で idle を流す。
## 攻撃の始まり・終わりは attack_started / attack_ended シグナルでも受け取れる。

@export var body: Node2D

## 攻撃アニメが始まったとき。
signal attack_started(animation_name: StringName)
## 攻撃アニメが終わった（通常終了・中断どちらも）とき。直後に RESET 姿勢・元の向きに戻っている。
signal attack_ended

@export var animation_player: AnimationPlayer
## 攻撃アニメが終わった/中断されたときに戻すアニメ名。
@export var reset_animation: StringName = &"RESET"

## 武器が攻撃アニメを再生中なら true（外からは読むだけ）。
var is_attacking: bool = false
## 再生中の攻撃アニメ名。攻撃中でなければ空。
var current_attack_animation: StringName = &""

## 攻撃していないときの向き（シーンに置いたときの rotation）。攻撃が終わったらここへ戻す。
var _rest_rotation: float = 0.0

func _ready() -> void:
	_rest_rotation = rotation
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)

## anim_name の攻撃アニメを最初から再生する。
## この武器にそのアニメが無ければ何もせず false を返す（呼び出し側はそれで「武器は動かなかった」と分かる）。
func play_attack_animation(anim_name: String) -> bool:
	if animation_player == null or not animation_player.has_animation(anim_name):
		return false
	# 前の攻撃が残っていれば片付けてから始める
	stop_attack_animation()
	# 同じ名前のアニメが再生中だと play() は頭に戻らないので、一度止める
	animation_player.stop()
	animation_player.play(anim_name)
	is_attacking = true
	current_attack_animation = anim_name
	attack_started.emit(current_attack_animation)
	return true

## 攻撃アニメを中断して RESET 姿勢・元の向きに戻す。攻撃中でなければ何もしない。
func stop_attack_animation() -> void:
	if not is_attacking:
		return
	# 攻撃アニメがまだ流れているときだけ RESET する（別のアニメに切り替わっていたら触らない）
	if animation_player and animation_player.current_animation == current_attack_animation:
		_play_reset()
	_end_attack()

## 攻撃の向きを変える。攻撃中ならいつ呼んでもよい。ゼロベクトルは向きが決まらないので無視する。
func set_attack_direction(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	rotation = direction.angle()

# --- 内部処理 ---

func _on_animation_finished(anim_name: StringName) -> void:
	if not is_attacking or anim_name != current_attack_animation:
		return
	_play_reset()
	_end_attack()

func _end_attack() -> void:
	is_attacking = false
	current_attack_animation = &""
	# set_attack_direction() で回した向きは RESET では戻らないので、ここで戻す
	rotation = _rest_rotation
	attack_ended.emit()

func _play_reset() -> void:
	animation_player.stop()
	if animation_player.has_animation(reset_animation):
		animation_player.play(reset_animation)

func _process(delta: float) -> void:
	if not is_attacking:
		var body_direction = body.get_facing_direction()

		if body_direction.x < 0:
			animation_player.play("idle_right")
		else:
			animation_player.play("idle_left")
