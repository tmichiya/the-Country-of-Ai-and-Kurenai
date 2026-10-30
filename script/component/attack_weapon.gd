class_name AttackWeapon
extends Node2D
## AttackAnimationRig から操作される武器。player / hakubo どちらの武器シーンのルートにも付けられる。
##
## 武器の AnimationPlayer を触るのはこのスクリプトだけ。Rig は
##   play_attack_animation() / stop_attack_animation() / set_attack_direction()
## を呼ぶだけで、武器の中身（アニメ名・向きの戻し方）は知らなくてよい。
##
## 攻撃中かどうかは is_attacking で分かる。攻撃していない間は _process で idle を流す。
## 攻撃が終わったら（通常終了・中断どちらも）、その瞬間の姿勢から RETURN_TIME かけて idle に戻る。
## 攻撃の始まり・終わりは attack_started / attack_ended シグナルでも受け取れる。

@export var body: Node2D

## 攻撃アニメが始まったとき。
signal attack_started(animation_name: StringName)
## 攻撃アニメが終わった（通常終了・中断どちらも）とき。ここから idle への補間が始まる。
signal attack_ended

@export var animation_player: AnimationPlayer

## 攻撃アニメへ切り替えるときの補間時間（秒）。
const ATTACK_BLEND_TIME := 0.16
## 攻撃が終わってから idle に戻るまでの時間（秒）。
const RETURN_TIME := 0.5
const RETURN_TRANS := Tween.TRANS_CUBIC
const RETURN_EASE := Tween.EASE_IN_OUT

## 武器が攻撃アニメを再生中なら true（外からは読むだけ）。
var is_attacking: bool = false
## 再生中の攻撃アニメ名。攻撃中でなければ空。
var current_attack_animation: StringName = &""

## 攻撃していないときの向き（シーンに置いたときの rotation）。攻撃が終わったらここへ戻す。
var _rest_rotation: float = 0.0

## idle へ戻る補間の途中なら true。
var _returning: bool = false
var _return_elapsed: float = 0.0
## 補間の出発点。Visual はルートから見た角度（ローカル）、ルートは攻撃方向に回っていた角度。
var _return_from_visual_rotation: float = 0.0
var _return_from_root_rotation: float = 0.0

@onready var _visual: Node2D = $Visual

func _ready() -> void:
	_rest_rotation = rotation
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)
		animation_player.mixer_applied.connect(_on_mixer_applied)

## anim_name の攻撃アニメを最初から再生する。
## この武器にそのアニメが無ければ何もせず false を返す（呼び出し側はそれで「武器は動かなかった」と分かる）。
func play_attack_animation(anim_name: String) -> bool:
	if animation_player == null or not animation_player.has_animation(anim_name):
		return false
	# 前の攻撃が残っていれば片付けてから始める
	stop_attack_animation()
	# idle へ戻る途中なら、その上書きをやめる（続けると攻撃アニメの回転を奪ってしまう）
	_returning = false
	# 同じ名前のアニメが再生中だと play() は頭に戻らない。そのときだけ止める。
	# stop(true) は「今の姿勢のまま止める」。引数なしの stop() は 0 秒目の姿勢に飛んでしまう。
	# （他のアニメから切り替えるときは stop しない。stop すると補間の出発点が無くなり ATTACK_BLEND_TIME が効かない）
	if animation_player.current_animation == anim_name:
		animation_player.stop(true)
	animation_player.play(anim_name, ATTACK_BLEND_TIME)
	is_attacking = true
	current_attack_animation = anim_name
	attack_started.emit(current_attack_animation)
	return true

## 攻撃アニメを中断する。攻撃中でなければ何もしない。
## 姿勢はその瞬間のまま残し、そこから idle へ補間して戻る（通常終了と同じ戻り方）。
func stop_attack_animation() -> void:
	if not is_attacking:
		return
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
	_end_attack()

func _end_attack() -> void:
	is_attacking = false
	current_attack_animation = &""
	# ルートの向きはここでは戻さない。今の向きを覚えておき、idle への補間と一緒に戻す。
	# （ここで一気に戻すと、補間の出発点が「攻撃方向を向いた姿勢」ではなく「直立」になってしまう）
	_return_from_root_rotation = rotation
	attack_ended.emit()

func _process(delta: float) -> void:
	_return_elapsed += delta
	if is_attacking:
		return

	var target := &"idle_right" if body.get_facing_direction().x < 0 else &"idle_left"
	# もう目的の idle が流れていれば何もしない（毎フレーム play すると補間が消える）
	if animation_player.current_animation == target:
		return
	var is_idle := animation_player.current_animation == &"idle_left" or animation_player.current_animation == &"idle_right"
	if is_idle:
		# idle どうしの左右切り替えは即座に
		animation_player.play(target)
		return

	# 攻撃などから戻るとき：今の角度（ローカル）を出発点にして補間を始める。
	# 位置などは AnimationPlayer の補間に任せ、回転だけ _on_mixer_applied で近回りに上書きする。
	_return_from_visual_rotation = _visual.rotation
	_return_elapsed = 0.0
	_returning = true
	animation_player.play(target, RETURN_TIME)

## AnimationPlayer がアニメを反映した直後に呼ばれる。idle へ戻る途中なら回転だけ上書きする。
func _on_mixer_applied() -> void:
	if is_attacking or not _returning:
		return
	var t: float = Tween.interpolate_value(0.0, 1.0, minf(_return_elapsed, RETURN_TIME), RETURN_TIME, RETURN_TRANS, RETURN_EASE)
	# 最後の 1 回は t = 1 で、ルートはぴったり元の向き・Visual は idle の角度になる
	if _return_elapsed >= RETURN_TIME:
		_returning = false

	# ルート：攻撃方向 → 元の向き
	rotation = lerp_angle(_return_from_root_rotation, _rest_rotation, t)

	# Visual：攻撃の最後の角度 → 今の idle の角度
	var anim := animation_player.get_animation(animation_player.current_animation)
	if anim == null:
		return
	var track := anim.find_track(^"Visual:rotation", Animation.TYPE_VALUE)
	if track == -1:
		return
	var idle_rotation: float = anim.value_track_interpolate(track, animation_player.current_animation_position)
	_visual.rotation = lerp_angle(_return_from_visual_rotation, idle_rotation, t)
