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

@onready var animation_player: AnimationPlayer = $AnimationPlayer

## 攻撃アニメへ切り替えるときの補間。
const ATTACK_BLEND_TIME := 0.16
const ATTACK_TRANS := Tween.TRANS_LINEAR  # 出だしは等速が一番なめらか（CUBIC の EASE_OUT だと最初の数フレームが速すぎる）
const ATTACK_EASE := Tween.EASE_IN_OUT
## 攻撃が終わってから idle に戻るときの補間。
const RETURN_TIME := 0.5
const RETURN_TRANS := Tween.TRANS_CUBIC
const RETURN_EASE := Tween.EASE_IN_OUT

## 武器が攻撃アニメを再生中なら true（外からは読むだけ）。
var is_attacking: bool = false
## 再生中の攻撃アニメ名。攻撃中でなければ空。
var current_attack_animation: StringName = &""

## 攻撃していないときの向き（シーンに置いたときの rotation）。攻撃が終わったらここへ戻す。
var _rest_rotation: float = 0.0
## ルートが最終的に向くべき角度（攻撃中は攻撃方向、それ以外は _rest_rotation）。
var _root_target_rotation: float = 0.0

## 姿勢の補間（アニメの切り替え時に「今画面に出ている姿勢」から次のアニメへつなぐ）。
## AnimationPlayer 自身の補間（play の custom_blend）は使わない。
## AnimationPlayer の補間は「AnimationPlayer の中で計算した値」から始まるので、
## こちらで回転を上書きしていると、画面の姿勢とずれた所から補間が始まってガクッとなるため。
var _transition_active: bool = false
var _transition_elapsed: float = 0.0
var _transition_duration: float = 0.0
var _transition_trans: Tween.TransitionType = Tween.TRANS_LINEAR
var _transition_ease: Tween.EaseType = Tween.EASE_IN_OUT
var _from_visual_position: Vector2 = Vector2.ZERO
var _from_visual_rotation: float = 0.0
var _from_root_rotation: float = 0.0

@onready var _visual: Node2D = $Visual
@onready var _particles: Node2D = $Visual/Particles

func _ready() -> void:
	_rest_rotation = rotation
	_root_target_rotation = rotation
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
	# 同じ名前のアニメが再生中だと play() は頭に戻らない。そのときだけ止める。
	# stop(true) は「今の姿勢のまま止める」。引数なしの stop() は 0 秒目の姿勢に飛んでしまう。
	if animation_player.current_animation == anim_name:
		animation_player.stop(true)
	animation_player.play(anim_name)
	# 今画面に出ている姿勢（idle でも、idle へ戻る途中でも、前の攻撃の途中でも）から攻撃アニメへつなぐ
	_begin_transition(ATTACK_BLEND_TIME, ATTACK_TRANS, ATTACK_EASE)
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

## 今の向き（body.get_anim_dir()）の idle 姿勢へ、補間なしで今すぐ合わせる。
## _process は body が操作ロック中だと idle を更新しないので、
## ロックしたまま向きだけ変える演出（エンディングなど）や reset のときはここを呼ぶ。
func snap_to_idle() -> void:
	if animation_player == null:
		return
	is_attacking = false
	current_attack_animation = &""
	_transition_active = false
	_root_target_rotation = _rest_rotation
	rotation = _rest_rotation
	var target := "idle_" + String(body.get_anim_dir())
	if animation_player.has_animation(target):
		animation_player.play(target)
		animation_player.seek(0.0, true)

## 攻撃の向きを変える。攻撃中ならいつ呼んでもよい。ゼロベクトルは向きが決まらないので無視する。
## 補間中なら、その補間の行き先として使われる。
func set_attack_direction(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	_root_target_rotation = direction.angle()
	if not _transition_active:
		rotation = _root_target_rotation

# --- 内部処理 ---

func _set_visible(visible: bool) -> void:
	_visual.visible = visible

func _on_animation_finished(anim_name: StringName) -> void:
	if not is_attacking or anim_name != current_attack_animation:
		return
	_end_attack()

func _end_attack() -> void:
	is_attacking = false
	current_attack_animation = &""
	# ルートの向きはここでは戻さない。行き先だけ決めておき、idle への補間と一緒に戻す。
	_root_target_rotation = _rest_rotation
	attack_ended.emit()

func _process(delta: float) -> void:
	if body.is_dead == true:
		_set_visible(false)
		return
	_set_visible(true)

	# player がそもそも動けないなら、return
	if body.is_processing_input() == false:
		return

	_transition_elapsed += delta
	if is_attacking:
		_particles.set_emitting(true)
		## idle 中は z index をanimation player 側で指定する
		## z-indexを body の y 座標を起点に y sort する
		_visual.z_index = 1 if _visual.position.y < 0 else -1	

		return
	else:
		## 以下は攻撃していないときの idle への補間

		_particles.set_emitting(false)

		var target := "idle_" + String(body.get_anim_dir())

		# もう目的の idle が流れていれば何もしない（毎フレーム play すると状態が分かりにくくなる）
		if animation_player.current_animation == target:
			return
		var is_idle := animation_player.current_animation == &"idle_left" or animation_player.current_animation == &"idle_right" or animation_player.current_animation == &"idle_up" or animation_player.current_animation == &"idle_down"
		animation_player.play(target)
		# idle どうしの左右切り替えは即座に。攻撃などから戻るときだけ、今の姿勢から補間する。
		if not is_idle:
			_begin_transition(RETURN_TIME, RETURN_TRANS, RETURN_EASE)

## 今画面に出ている姿勢を出発点として覚え、duration 秒かけて「AnimationPlayer が出す姿勢」へつなぐ。
func _begin_transition(duration: float, trans: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	_from_visual_position = _visual.position
	_from_visual_rotation = _visual.rotation
	_from_root_rotation = rotation
	_transition_elapsed = 0.0
	_transition_duration = duration
	_transition_trans = trans
	_transition_ease = ease_type
	_transition_active = duration > 0.0
	if not _transition_active:
		rotation = _root_target_rotation

## AnimationPlayer がアニメを反映した直後に呼ばれる。
## このとき Visual にはアニメの値がそのまま入っているので、それを「行き先」として出発点から補間した値で上書きする。
func _on_mixer_applied() -> void:
	if not _transition_active:
		return
	var t: float = Tween.interpolate_value(0.0, 1.0, minf(_transition_elapsed, _transition_duration), _transition_duration, _transition_trans, _transition_ease)
	# 最後の 1 回は t = 1 で、アニメの値・行き先の向きにぴったり合う
	if _transition_elapsed >= _transition_duration:
		_transition_active = false

	_visual.position = _from_visual_position.lerp(_visual.position, t)
	# 回転は近回り（lerp_angle）でつなぐ
	_visual.rotation = lerp_angle(_from_visual_rotation, _visual.rotation, t)
	rotation = lerp_angle(_from_root_rotation, _root_target_rotation, t)
