class_name AttackWeapon
extends Node2D
## AttackAnimationRig から操作される武器。player / hakubo どちらの武器シーンのルートにも付けられる。
##
## 攻撃中かどうかは is_attacking で分かる。攻撃していない間に idle モーションを流したい場合は、
## このスクリプトを extends した武器専用スクリプトを作り、
##   - _process で is_attacking が false のときに idle を流す
##   - または attack_ended シグナルで idle を再開する
## のどちらかで実装する。

@export var body: Node2D

## 攻撃アニメが始まった（Rig が武器アニメを再生した）とき。
signal attack_started(animation_name: StringName)
## 攻撃アニメが終わった（通常終了・中断どちらも）とき。直後に RESET 姿勢になっている。
signal attack_ended

@export var animation_player: AnimationPlayer

## 武器が攻撃アニメを再生中なら true。Rig だけが書き換える（外からは読むだけ）。
var is_attacking: bool = false
## 再生中の攻撃アニメ名。攻撃中でなければ空。
var current_attack_animation: StringName = &""

func notify_attack_started(animation_name: StringName) -> void:
	is_attacking = true
	current_attack_animation = animation_name
	attack_started.emit(animation_name)

func notify_attack_ended() -> void:
	if not is_attacking:
		return
	is_attacking = false
	current_attack_animation = &""
	attack_ended.emit()
