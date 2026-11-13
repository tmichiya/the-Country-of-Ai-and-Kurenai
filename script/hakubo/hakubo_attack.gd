class_name HakuboAttack
extends Node2D
## 薄暮の攻撃シーンに共通する部分。各攻撃スクリプトは `extends HakuboAttack` にする。
##
## 派生側の _ready() は、最初に super() を呼ぶ（ここでヒットボックスとアニメ終了のシグナルをつなぐ）。
## フラグは攻撃インスタンスが持つ。攻撃は毎回 instantiate され、終われば（パリィ・強制終了を含めて）破棄されるので、
## アニメが途中で止まっても値が次の攻撃へ持ち越されることはない。

signal attack_finished
signal parried(position: Vector2)

## 攻撃ごとの値は各シーンのインスペクタで設定する。
@export var damage: float = 30.0

## true のあいだ、薄暮は緊急ダッシュでこの攻撃を打ち切ってよい。
## 攻撃開始時の値はシーンごとにインスペクタで決め、途中の切り替えはアニメの set_can_emergency_dash() で行う。
@export var can_emergency_dash: bool = false

## 持ち主（hakubo）が add_child の前に渡す。体と武器のアニメをまとめて流す。
var animation_rig: AttackAnimationRig
var paint_layer: Node2D = null
var mana_cost: float = 10.0

var can_parry: bool = true
## 予備動作中か。迅雷の追尾や、訓練用の標的の色分けに使う。
var is_telegraphing: bool = false

@onready var hakubo = get_parent() as CharacterBody2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
## 弾を撃つだけの攻撃（唐竹の親など）には無い。
@onready var hit_box: Area2D = get_node_or_null("HitBox")

func _ready() -> void:
	if hit_box:
		hit_box.area_entered.connect(_on_hitbox_area_entered)
	animation_player.animation_finished.connect(_on_animation_finished)

## 派生側で上書きして、最後のアニメが終わったら finish_attack() を呼ぶ。
func _on_animation_finished(_anim_name: String) -> void:
	pass

## 攻撃を終える。通常終了・パリィのどちらもここを通す。
func finish_attack() -> void:
	if is_queued_for_deletion():
		return
	attack_finished.emit()
	queue_free()

# --- アニメのメソッドトラックから呼ぶもの ---

func enable_hitbox() -> void:
	_set_hitbox_disabled(false)

func disable_hitbox() -> void:
	_set_hitbox_disabled(true)

func change_can_parry_to(value: bool) -> void:
	can_parry = value

func switch_is_telegraphing_to(value: bool) -> void:
	is_telegraphing = value

func set_can_emergency_dash(value: bool) -> void:
	can_emergency_dash = value

func spend_mana() -> bool:
	if hakubo and hakubo.has_node("ManaComponent"):
		var mana_component = hakubo.get_node("ManaComponent") as ManaComponent
		if mana_component:
			return mana_component.spend(mana_cost, ManaComponent.Reason.SPEND)
	return false

func is_playing_telegraph_animation() -> bool:
	return is_telegraphing

# --- 当たり判定 ---

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("parry") and can_parry and _try_consume_parry(area):
		_on_parried(area)
		return

	if area.is_in_group("player"):
		_on_player_hit(area.get_parent())

## 当たった後の処理を足したい攻撃（一度当てたら判定を消す、など）はここを上書きして super(player) を呼ぶ。
func _on_player_hit(player: Node) -> void:
	player.take_damage(damage, ManaComponent.Reason.TAKE_DAMAGE)

func _on_parried(area: Area2D) -> void:
	parried.emit(_to_screen_uv(area.global_position))
	can_parry = false
	finish_attack()

func _try_consume_parry(area: Area2D) -> bool:
	var parry_node = area.get_parent()
	if parry_node and parry_node.has_method("try_consume"):
		return parry_node.try_consume()
	return true

## パリィ演出（画面の放射）用に、画面上の位置を 0〜1 に正規化して返す。
func _to_screen_uv(world_position: Vector2) -> Vector2:
	var vp := get_viewport()
	return (vp.get_canvas_transform() * world_position) / vp.get_visible_rect().size

func _set_hitbox_disabled(value: bool) -> void:
	if hit_box == null:
		return
	for shape in hit_box.get_children():
		if shape is CollisionShape2D or shape is CollisionPolygon2D:
			shape.set_deferred("disabled", value)
