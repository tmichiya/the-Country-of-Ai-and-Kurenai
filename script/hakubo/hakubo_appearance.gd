class_name HakuboAppearance
extends Node
## 薄暮の「形態ごとの見た目」（黒く染まる・影と光など）を受け持つ。
## hakubo.gd からは apply_look() / deepen_corruption() / tween_corruption() だけを呼ぶ。

@export var sprite: AnimatedSprite2D
@export var shadow: Node2D
@export var body_light: PointLight2D

## 1・2 本目を折るたびに足す染まり具合（追い詰めるほど呪いが濃くなる）
@export var corruption_per_break: float = 0.05

var _material: ShaderMaterial
var _look: HakuboFormLook
## 形態の基本の染まり具合。tween_corruption() で書き換わる。
var _base_corruption: float = 0.0
## 折られて上乗せされたぶん。形態が変わると 0 に戻る。
var _corruption_bonus: float = 0.0
var _corruption: float = 0.0
var _look_tween: Tween
var _corruption_tween: Tween

var _shadow_base_scale: Vector2 = Vector2.ONE
var _shadow_base_alpha: float = 1.0


func _ready() -> void:
	_material = sprite.material as ShaderMaterial
	_shadow_base_scale = shadow.scale
	_shadow_base_alpha = shadow.modulate.a


## 形態の見た目に切り替える。duration > 0 なら Tween でゆっくり移る。
func apply_look(look: HakuboFormLook, duration: float = 0.0) -> void:
	if look == null:
		return
	_look = look
	_base_corruption = look.corruption
	_corruption_bonus = 0.0
	_kill(_look_tween)

	var shadow_scale := _shadow_base_scale * look.shadow_scale
	var shadow_alpha := _shadow_base_alpha * look.shadow_alpha

	if duration <= 0.0:
		_kill(_corruption_tween)
		_set_corruption(_base_corruption)
		body_light.color = look.light_color
		shadow.scale = shadow_scale
		shadow.modulate.a = shadow_alpha
		return

	_tween_corruption_to(_base_corruption, duration)
	_look_tween = create_tween().set_parallel(true)
	_look_tween.tween_property(body_light, "color", look.light_color, duration)
	_look_tween.tween_property(shadow, "scale", shadow_scale, duration)
	_look_tween.tween_property(shadow, "modulate:a", shadow_alpha, duration)


## 1・2 本目を折られたときに呼ぶ。少しだけ黒さを増す。
func deepen_corruption(duration: float = 0.3) -> void:
	_corruption_bonus += corruption_per_break
	_tween_corruption_to(_base_corruption + _corruption_bonus, duration)


## 染まり具合だけを value へ duration 秒で動かす（撃破や呪いの離散の演出用）。
func tween_corruption(value: float, duration: float) -> void:
	_base_corruption = value
	_corruption_bonus = 0.0
	_tween_corruption_to(value, duration)


func _tween_corruption_to(value: float, duration: float) -> void:
	_kill(_corruption_tween)
	_corruption_tween = create_tween()
	_corruption_tween.tween_method(_set_corruption, _corruption, clampf(value, 0.0, 1.0), duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_corruption(value: float) -> void:
	_corruption = value
	# _ready() より先に呼ばれても効くよう、ここでも取りに行く
	if _material == null and sprite:
		_material = sprite.material as ShaderMaterial
	if _material:
		_material.set_shader_parameter("corruption", value)


func _kill(tw: Tween) -> void:
	if tw and tw.is_valid():
		tw.kill()
