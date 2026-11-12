class_name HakuboAppearance
extends Node
## 薄暮の「形態ごとの見た目」（黒く染まる・片目・滴り・残像・グリッチ・影と光）を受け持つ。
## hakubo.gd からは apply_look() / deepen_corruption() / tween_corruption() / play_disperse() だけを呼ぶ。

const AFTERIMAGE_SHADER := preload("res://shader/hakubo_afterimage.gdshader")

@export var sprite: AnimatedSprite2D
@export var visual: Node2D
@export var shadow: Node2D
@export var body_light: PointLight2D
@export var eye: HakuboEye
@export var drip_particles: GPUParticles2D
## 呪いが抜けるときに体から上へ散る紅の粒
@export var disperse_particles: GPUParticles2D

## 1・2 本目を折るたびに足す染まり具合（追い詰めるほど呪いが濃くなる）
@export var corruption_per_break: float = 0.05

@export_group("残像")
@export var afterimage_interval: float = 0.05
@export var afterimage_lifetime: float = 0.3
@export var afterimage_pool_size: int = 8
@export var afterimage_color_dark: Color = Color(0.06, 0.0, 0.04, 0.55)
@export var afterimage_color_red: Color = Color(0.74, 0.0, 0.21, 0.45)

@export_group("グリッチ")
@export var glitch_interval_min: float = 2.0
@export var glitch_interval_max: float = 5.0

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

var _afterimage_enabled: bool = false
var _afterimage_timer: float = 0.0
var _afterimages: Array[Sprite2D] = []
var _afterimage_next: int = 0

var _glitch_enabled: bool = false
var _glitch_timer: float = 0.0
## 1px ずらしている残りフレーム数
var _glitch_frames: int = 0

## 持ち主の hakubo。ダッシュ中かどうかを見る（hakubo.gd の型に依存しないよう型は付けない）
@onready var _body = get_parent()


func _ready() -> void:
	_material = sprite.material as ShaderMaterial
	_shadow_base_scale = shadow.scale
	_shadow_base_alpha = shadow.modulate.a
	_build_afterimage_pool()


func _process(delta: float) -> void:
	_update_afterimage(delta)
	_update_glitch(delta)


## 形態の見た目に切り替える。duration > 0 なら Tween でゆっくり移る。
func apply_look(look: HakuboFormLook, duration: float = 0.0) -> void:
	if look == null:
		return
	_look = look
	_base_corruption = look.corruption
	_corruption_bonus = 0.0
	_kill(_look_tween)

	_afterimage_enabled = look.afterimage_on_dash
	_set_glitch_enabled(look.glitch)
	drip_particles.amount_ratio = look.drip_particles
	drip_particles.emitting = look.drip_particles > 0.0

	var shadow_scale := _shadow_base_scale * look.shadow_scale
	var shadow_alpha := _shadow_base_alpha * look.shadow_alpha

	if duration <= 0.0:
		_kill(_corruption_tween)
		_set_corruption(_base_corruption)
		eye.set_look(look.eye_enabled, look.eye_energy, look.eye_pulse, look.eye_trail)
		body_light.color = look.light_color
		shadow.scale = shadow_scale
		shadow.modulate.a = shadow_alpha
		_hide_all_afterimages()
		return

	_tween_corruption_to(_base_corruption, duration)
	# 目は今の明るさから新しい明るさへ灯していく（消すときも同じ）
	var eye_from := eye.energy
	eye.set_look(look.eye_enabled, look.eye_energy, look.eye_pulse, look.eye_trail)
	var eye_to := eye.energy
	eye.energy = eye_from
	_look_tween = create_tween().set_parallel(true)
	_look_tween.tween_property(eye, "energy", eye_to, duration)
	_look_tween.tween_property(body_light, "color", look.light_color, duration)
	_look_tween.tween_property(shadow, "scale", shadow_scale, duration)
	_look_tween.tween_property(shadow, "modulate:a", shadow_alpha, duration)


## 1・2 本目を折られたときに呼ぶ。少しだけ黒さを増す。
func deepen_corruption(duration: float = 0.3) -> void:
	_corruption_bonus += corruption_per_break
	_tween_corruption_to(_base_corruption + _corruption_bonus, duration)


## 染まり具合だけを value へ duration 秒で動かす（撃破演出用）。
func tween_corruption(value: float, duration: float) -> void:
	_base_corruption = value
	_corruption_bonus = 0.0
	_tween_corruption_to(value, duration)


## 呪いが体から抜けて上へ散る粒を出す。
func play_disperse() -> void:
	disperse_particles.restart()


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


# --- 残像 -------------------------------------------------------------

## 残像用の Sprite2D を先に作っておき、使い回す（ダッシュのたびに new しない）。
func _build_afterimage_pool() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = AFTERIMAGE_SHADER
	for i in afterimage_pool_size:
		var ghost := Sprite2D.new()
		ghost.top_level = true   # 体が動いても、置いた場所に残る
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.material = mat
		ghost.visible = false
		ghost.z_index = 1   # 薄暮本体（z_index 2）の後ろ、床の上
		add_child(ghost)
		_afterimages.append(ghost)


## ダッシュ中だけ、一定間隔で今のフレームを複製して消していく。
func _update_afterimage(delta: float) -> void:
	if not _afterimage_enabled or _body == null or _body.movement_state != _body.MovementState.DASH:
		_afterimage_timer = 0.0
		return
	_afterimage_timer -= delta
	if _afterimage_timer > 0.0:
		return
	_afterimage_timer = afterimage_interval
	_spawn_afterimage()


func _spawn_afterimage() -> void:
	var ghost := _afterimages[_afterimage_next]
	_afterimage_next = (_afterimage_next + 1) % _afterimages.size()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.global_transform = sprite.global_transform
	ghost.modulate = afterimage_color_dark.lerp(afterimage_color_red, randf())
	ghost.visible = true
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, afterimage_lifetime)
	tw.tween_callback(ghost.hide)


func _hide_all_afterimages() -> void:
	for ghost in _afterimages:
		ghost.visible = false


# --- 1px のグリッチ ----------------------------------------------------

func _set_glitch_enabled(enabled: bool) -> void:
	_glitch_enabled = enabled
	_glitch_frames = 0
	visual.position.x = 0.0
	_glitch_timer = randf_range(glitch_interval_min, glitch_interval_max)


## 数秒に一度、体を 1px 横にずらして 1〜2 フレームで戻す。
func _update_glitch(delta: float) -> void:
	if _glitch_frames > 0:
		_glitch_frames -= 1
		if _glitch_frames == 0:
			visual.position.x = 0.0
		return
	if not _glitch_enabled:
		return
	_glitch_timer -= delta
	if _glitch_timer > 0.0:
		return
	_glitch_timer = randf_range(glitch_interval_min, glitch_interval_max)
	_glitch_frames = randi_range(1, 2)
	visual.position.x = 1.0 if randf() < 0.5 else -1.0


func _kill(tw: Tween) -> void:
	if tw and tw.is_valid():
		tw.kill()
