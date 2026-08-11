extends Node2D

var shake_strength: float = 0.0
var shake_decay: float = 8.0
var tw: Tween = null

var hitstop_active: bool = false

const FLASH_AI := Color(0.24, 0.44, 0.91)   # 藍
const FLASH_KURENAI := Color(1.0, 0.24, 0.33)    # 紅
const FLASH_WHITE := Color(0.96, 0.95, 0.92)

@onready var flash_rect: ColorRect = $CanvasLayer/ColorRect

func slowmotion(val: float, duration: float) -> void:
	if hitstop_active:
		return
	hitstop_active = true
	var original_time_scale = Engine.time_scale
	Engine.time_scale = val
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = original_time_scale
	hitstop_active = false

func shake(strength: float) -> void:
	print("Camera shake called with strength: %f" % strength)
	shake_strength = max(shake_strength, strength)

func _process(delta: float) -> void:
	if shake_strength > 0.0:
		print("Applying camera shake with strength: %f" % shake_strength)
		shake_strength = move_toward(shake_strength, 0.0, shake_decay * delta)
		var cam = get_viewport().get_camera_2d()
		if cam:
			cam.offset = Vector2(
				randf_range(-shake_strength, shake_strength), 
				randf_range(-shake_strength, shake_strength)
			)

func flash_impact(color: Color, strength: float, duration: float, pos: Vector2) -> void:
	var mat = flash_rect.material as ShaderMaterial
	position = pos
	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("flash_strength", strength)

	print("Flash impact called with color: %s, strength: %f, duration: %f" % [color, strength, duration])

	tw = create_tween()
	tw.tween_method(
		func(v): mat.set_shader_parameter("strength", v),
		strength, 0.0, duration
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func _kill_flash_tween() -> void:
	if tw and tw.is_valid():
		tw.kill()
