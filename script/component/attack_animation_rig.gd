class_name AttackAnimationRig
extends Node
## 攻撃インスタンスから「体」と「武器」のアニメーションをまとめて再生するための部品。
##
## 使い方:
##   1. 持ち主（player / hakubo）が攻撃インスタンスを add_child する前に
##      instance.animation_rig = この Rig を代入する（依存性の注入）。
##   2. 攻撃インスタンスは _ready() などで
##      animation_rig.play_attack_animation("attack_xxx", self, 攻撃方向) を呼ぶ。
##      攻撃の途中で向きが変わるときは update_attack_direction(新しい方向) を呼ぶ。
##   3. 体・武器の AnimationPlayer に同じ名前のアニメがあれば、それぞれ再生される。
##      無ければその側は何もしない（武器が無いキャラ、体アニメが無い攻撃でも動く）。
##   4. 攻撃インスタンスがツリーから外れたら（通常終了・パリィ・強制終了どれでも）
##      自動でリセット姿勢に戻す。攻撃側で後始末を書く必要はない。

@export var body: Node2D
@export var body_animation_player: AnimationPlayer
## 武器は任意。未設定なら体だけを動かす。
@export var weapon: AttackWeapon

## 攻撃アニメが終わった/中断されたときに戻すアニメ名。
@export var body_reset_animation: StringName = &"reset"
@export var weapon_reset_animation: StringName = &"RESET"

## 今この Rig が再生させているアニメ名（再生していなければ空）。
var _body_animation: StringName = &""
var _weapon_animation: StringName = &""
## 再生を依頼した攻撃インスタンス。古いインスタンスの退場で新しい攻撃を止めないために覚えておく。
var _requester: Node = null
## 攻撃していないときの武器の向き（シーンに置いたときの rotation）。攻撃が終わったらここへ戻す。
var _weapon_rest_rotation: float = 0.0

func _ready() -> void:
	if weapon:
		_weapon_rest_rotation = weapon.rotation
	if body_animation_player:
		body_animation_player.animation_finished.connect(_on_body_animation_finished)
	if weapon and weapon.animation_player:
		weapon.animation_player.animation_finished.connect(_on_weapon_animation_finished)

## 体と武器で animation_name を最初から再生する。
## requester を渡すと、そのノードがツリーから外れた時点で自動的に stop_attack_animation() する。
## direction は攻撃の向き（長さは問わない）。武器の攻撃アニメを流すときに武器をその向きに回す。
func play_attack_animation(animation_name: StringName, requester: Node = null, direction: Vector2 = Vector2.RIGHT) -> void:
	# 前の攻撃アニメが残っていれば片付ける（退場通知の解除・武器の is_attacking も戻る）
	stop_attack_animation()

	if body_animation_player and body_animation_player.has_animation(animation_name):
		# 同じ名前のアニメが再生中だと play() は頭に戻らないので、一度止める
		body_animation_player.stop()
		body_animation_player.play(animation_name)
		_body_animation = animation_name
	else:
		_body_animation = &""

	var weapon_player := _get_weapon_animation_player()
	if weapon_player and weapon_player.has_animation(animation_name):
		weapon_player.stop()
		weapon_player.play(animation_name)
		_weapon_animation = animation_name
		weapon.notify_attack_started(animation_name)

		update_attack_direction(direction)
	else:
		_weapon_animation = &""

	if requester and (_body_animation != &"" or _weapon_animation != &""):
		_requester = requester
		requester.tree_exiting.connect(_on_requester_exiting, CONNECT_ONE_SHOT)

## Rig が再生させた攻撃アニメを止めてリセット姿勢に戻す。
## 体側で damage など「Rig 以外が流したアニメ」が再生中なら、そちらは触らない。
func stop_attack_animation() -> void:
	_disconnect_requester()

	if body_animation_player and _body_animation != &"":
		if body_animation_player.current_animation == _body_animation:
			_play_reset(body_animation_player, body_reset_animation)
		_body_animation = &""

	var weapon_player := _get_weapon_animation_player()
	if weapon_player and _weapon_animation != &"":
		if weapon_player.current_animation == _weapon_animation:
			_play_reset(weapon_player, weapon_reset_animation)
		_weapon_animation = &""
		_restore_weapon_direction()
		weapon.notify_attack_ended()

## 任意のタイミングで武器の向きを変える（攻撃の途中で狙い直すときなど）。
## ゼロベクトルは向きが決まらないので無視する。
func update_attack_direction(direction: Vector2) -> void:
	if weapon == null or direction == Vector2.ZERO:
		return
	weapon.rotation = direction.angle()

func is_playing_attack_animation() -> bool:
	return _body_animation != &"" or _weapon_animation != &""

# --- 内部処理 ---

func _get_weapon_animation_player() -> AnimationPlayer:
	if weapon:
		return weapon.animation_player
	return null

## update_attack_direction() で回した武器の向きを元に戻す。
## RESET アニメは武器の中身（Visual など）しか戻さないので、Rig が回したルートの rotation は Rig が戻す。
func _restore_weapon_direction() -> void:
	if weapon:
		weapon.rotation = _weapon_rest_rotation

func _play_reset(player: AnimationPlayer, reset_name: StringName) -> void:
	player.stop()
	if player.has_animation(reset_name):
		player.play(reset_name)

func _on_body_animation_finished(anim_name: StringName) -> void:
	if anim_name != _body_animation:
		return
	_body_animation = &""
	_play_reset(body_animation_player, body_reset_animation)

func _on_weapon_animation_finished(anim_name: StringName) -> void:
	if anim_name != _weapon_animation:
		return
	_weapon_animation = &""
	_play_reset(weapon.animation_player, weapon_reset_animation)
	_restore_weapon_direction()
	weapon.notify_attack_ended()

func _on_requester_exiting() -> void:
	_requester = null
	# 持ち主ごとシーンが破棄されている最中なら何もしない
	if not is_inside_tree() or is_queued_for_deletion():
		return
	stop_attack_animation()

func _disconnect_requester() -> void:
	if is_instance_valid(_requester) and _requester.tree_exiting.is_connected(_on_requester_exiting):
		_requester.tree_exiting.disconnect(_on_requester_exiting)
	_requester = null
