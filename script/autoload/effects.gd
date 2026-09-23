extends Node

@onready var flash_rect: ColorRect = $CanvasLayer/ColorRect
@onready var mat = flash_rect.material as ShaderMaterial
@onready var distortion_rect: ColorRect = $CanvasLayer/DistortionRect
@onready var distortion_mat = distortion_rect.material as ShaderMaterial
@onready var circle_dithering : ColorRect = $CanvasLayer/CircleDithering
@onready var circle_dithering_mat = circle_dithering.material as ShaderMaterial

var shake_strength: float = 0.0
var shake_decay: float = 8.0
var tw: Tween = null

## 直近のフレームで camera.offset に足した「揺れぶん」だけの量。
## 揺れの影響を受けたくない側（会話ボックスなど）は、この値を打ち消せばよい。
##
## camera.offset は Camera.set_offset() による演出用オフセットにも使われるので、
## 「offset 全体」ではなく「揺れぶんだけ」を切り分けて公開している。
var shake_offset: Vector2 = Vector2.ZERO
## 揺れを適用しているカメラ。部屋の切り替えで差し替わったのを検知するために持つ。
var _shake_cam: Camera2D = null

var can_shake_decay : bool = true

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

func normal_transition(callback: Callable) -> void:
	await Effects.fade_in(1.0)
	callback.call()
	await get_tree().create_timer(0.5, true, false, true).timeout
	await Effects.fade_out(1.0)

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

var smooth_shake_tw: Tween = null
func smooth_shake(strength_from: float, strength_to: float, duration: float) -> void:
	smooth_shake_tw = null
	smooth_shake_tw = create_tween()
	smooth_shake_tw.tween_method(
		func(v): shake_strength = v,
		strength_from, strength_to, duration
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await smooth_shake_tw.finished

func kill_smooth_shake() -> void:
	if smooth_shake_tw and smooth_shake_tw.is_valid():
		smooth_shake_tw.kill()
		smooth_shake_tw = null

func set_can_shake_decay(to: bool) -> void:
	can_shake_decay = to

func flash_impact(color: Color, strength: float, duration: float, uv: Vector2) -> void:
	_kill_flash_tween()
	
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	# シーン上で visible=false になっていても確実に描画されるよう、ここで表示ONにする。
	flash_rect.visible = true
	mat.set_shader_parameter("center", uv)
	mat.set_shader_parameter("aspect", viewport_size.x / viewport_size.y)
	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("strength", strength)

	tw = create_tween()
	tw.tween_method(
		func(v): mat.set_shader_parameter("strength", v),
		strength, 0.0, duration
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# フラッシュが終わったら非表示に戻す（描画コスト削減）。
	tw.tween_callback(func(): flash_rect.visible = false)

func _kill_flash_tween() -> void:
	if tw and tw.is_valid():
		tw.kill()
		tw = null

func set_visible_fade(visible: bool) -> void:
	circle_dithering.visible = visible

func set_fade_alpha(alpha: float) -> void:
	circle_dithering_mat.set_shader_parameter("alpha", alpha)

func set_fade_color(color_rgb: Vector3) -> void:
	circle_dithering_mat.set_shader_parameter("fade_color_rgb", color_rgb)

func set_fade_parameter(strength: float) -> void:
	circle_dithering_mat.set_shader_parameter("strength", strength)

func fade_in(duration: float, from: float = -1.0) -> void:
	circle_dithering.visible = true
	circle_dithering_mat.set_shader_parameter("strength", from)
	var tw := create_tween()
	tw.tween_property(circle_dithering_mat, "shader_parameter/strength", 1.0, duration)
	await tw.finished

func fade_out(duration: float = 1.0, from: float = 1.0) -> void:
	circle_dithering.visible = true
	circle_dithering_mat.set_shader_parameter("strength", from)
	var tw := create_tween()
	tw.tween_property(circle_dithering_mat, "shader_parameter/strength", -1.0, duration)
	await tw.finished
	circle_dithering.visible = false

func _ready() -> void:
	mat.set_shader_parameter("strength", 0.0)

func _process(delta: float) -> void:
	# ゲーム本体は SubViewport 内にあるため、ルートの get_camera_2d() では
	# アクティブカメラを取得できない（null になる）。Camera autoload 経由で参照する。
	var cam: Camera2D = Camera.camera

	# 部屋の切り替えでカメラが差し替わったら、前のカメラに足した揺れは追わない
	if cam != _shake_cam:
		_shake_cam = cam
		shake_offset = Vector2.ZERO

	if shake_strength > 0.0 and can_shake_decay:
		shake_strength = move_toward(shake_strength, 0.0, shake_decay * delta)

	if cam == null:
		shake_offset = Vector2.ZERO
		return

	# 【重要】camera.offset は揺れ専用ではない。
	# Camera.set_offset()（オープニングの (0,-80) など）も同じ offset を使う。
	# 以前はここで offset を丸ごと上書きし、揺れ終わりに 0 へ戻していたため、
	# 揺れが起きるたびに演出用のオフセットが消えてしまっていた。
	#
	# 「前フレームに足した揺れを引いて素の値に戻す → 新しい揺れを足す」形にすると、
	#   ・演出用オフセットを壊さない
	#   ・揺れぶんが shake_offset として外から分かる（会話ボックスの打ち消しに使う）
	# の両方を満たせる。
	var base: Vector2 = cam.offset - shake_offset

	if shake_strength > 0.0:
		shake_offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
	else:
		shake_offset = Vector2.ZERO

	cam.offset = base + shake_offset
