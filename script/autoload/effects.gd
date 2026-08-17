extends Node

@onready var flash_rect: ColorRect = $CanvasLayer/ColorRect
@onready var mat = flash_rect.material as ShaderMaterial
@onready var distortion_rect: ColorRect = $CanvasLayer/DistortionRect
@onready var distortion_mat = distortion_rect.material as ShaderMaterial

var shake_strength: float = 0.0
var shake_decay: float = 8.0
var tw: Tween = null

var hitstop_active: bool = false

const FLASH_AI := Color(0.24, 0.44, 0.91)   # 藍
const FLASH_KURENAI := Color(1.0, 0.24, 0.33)    # 紅
const FLASH_WHITE := Color(0.96, 0.95, 0.92)



## 時空が歪んでシームレスに切り替わる演出。
## 画面が最も歪んで白く発光した「見えない瞬間」に callback を呼ぶので、
## callback の中で部屋の visible を切り替えれば、
## 読み込みなしでシームレスに景色が変わったように見える。
func warp_transition(callback: Callable) -> void:
	var tw := create_tween()
	tw.tween_method(
		func(v): distortion_mat.set_shader_parameter("distortion", v),
		0.0, 1.0, 0.6
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished

	flash_impact(FLASH_WHITE, 1.0, 0.5, Vector2(0.5, 0.5))
	shake(6.0)
	await get_tree().create_timer(0.15, true, false, true).timeout

	callback.call()

	var tw2 := create_tween()
	tw2.tween_method(
		func(v): distortion_mat.set_shader_parameter("distortion", v),
		1.0, 0.0, 0.7
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw2.finished

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
	shake_strength = max(shake_strength, strength)

func flash_impact(color: Color, strength: float, duration: float, uv: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	mat.set_shader_parameter("center", uv)
	mat.set_shader_parameter("aspect", viewport_size.x / viewport_size.y)
	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("strength", strength)

	tw = create_tween()
	tw.tween_method(
		func(v): mat.set_shader_parameter("strength", v),
		strength, 0.0, duration
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func _kill_flash_tween() -> void:
	if tw and tw.is_valid():
		tw.kill()

func _ready() -> void:
	mat.set_shader_parameter("strength", 0.0)
	print("Effects ready")

func _process(delta: float) -> void:
	if shake_strength > 0.0:
		shake_strength = move_toward(shake_strength, 0.0, shake_decay * delta)
		var cam = get_viewport().get_camera_2d()
		if cam:
			cam.offset = Vector2(
				randf_range(-shake_strength, shake_strength), 
				randf_range(-shake_strength, shake_strength)
			)
