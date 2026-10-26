extends Node

@onready var flash_rect: ColorRect = $CanvasLayer/ColorRect
@onready var mat = flash_rect.material as ShaderMaterial
@onready var distortion_rect: ColorRect = $CanvasLayer/DistortionRect
@onready var distortion_mat = distortion_rect.material as ShaderMaterial
@onready var circle_dithering : ColorRect = $CanvasLayer/CircleDithering
@onready var circle_dithering_mat = circle_dithering.material as ShaderMaterial

const WHITE_VEC3 = Vector3(1.0, 1.0, 1.0)
const BLACK_VEC3 = Vector3(0.05, 0.05, 0.05)
const RED_VEC3 = Vector3(1.0, 0.24, 0.33)

var shake_strength: float = 0.0
var shake_decay: float = 8.0
var tw: Tween = null

## 直近のフレームで camera.offset に足した揺れぶん。
## 揺れの影響を受けたくない側（会話ボックスなど）は、この値を打ち消せばよい。
var shake_offset: Vector2 = Vector2.ZERO
## 揺れを適用しているカメラ。部屋の切り替えで差し替わったのを検知するために持つ。
var _shake_cam: Camera2D = null

var can_shake_decay : bool = true

var hitstop_active: bool = false

const FLASH_AI := Color(0.24, 0.44, 0.91)
const FLASH_KURENAI := Color(1.0, 0.24, 0.33)
const FLASH_WHITE := Color(0.96, 0.95, 0.92)

## 1 回の暗転が終わった（または割り込まれた）ことを知らせる。引数はその暗転の世代番号。
signal _fade_ended(generation: int)

## いま暗転を動かしている Tween（1 本だけ）
var _fade_tween: Tween = null
## 暗転を始めるたびに増える世代番号。await 後に「自分がまだ最新か」を確かめるのに使う。
var _fade_generation: int = 0
## 暗転（画面遷移）用の色。set_fade_color() で決める。ダメージ演出の色とは分けて持つ。
var _fade_color: Vector3 = BLACK_VEC3
## fade_in を始めてから fade_out を終えるまで true。
## この間はダメージ等の flash_fade() を出さない（暗転を勝手に明けさせないため）。
var _screen_held: bool = false

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

func normal_transition(callback: Callable, color_vec3: Vector3 = Vector3(-1,-1,-1)) -> void:
	if not color_vec3.is_equal_approx(Vector3(-1,-1,-1)):
		Effects.set_fade_color(color_vec3)
	# 別の暗転に割り込まれた＝別の遷移が画面を持っていったので、こちらは降りる
	if not await Effects.fade_in(1.0):
		return
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

## 暗転（画面遷移）の色を決める。次の fade_in / fade_out からこの色が使われる。
func set_fade_color(color_rgb: Vector3) -> void:
	_fade_color = color_rgb
	circle_dithering_mat.set_shader_parameter("fade_color_rgb", color_rgb)

func set_fade_parameter(strength: float) -> void:
	circle_dithering_mat.set_shader_parameter("strength", strength)

## 画面遷移の暗転を始める。
## 最後まで暗転しきったら true、途中で別の暗転に割り込まれたら false を返す。
## from を省略すると、暗転が動いている途中なら「今の濃さ」から続ける（ぶつ切れ防止）。
func fade_in(duration: float, from: float = NAN) -> bool:
	_screen_held = true
	_apply_transition_look()
	var start: float = from if not is_nan(from) else _current_strength_or(-1.0)
	return await _play_fade(start, 1.0, duration)

## 画面遷移の暗転を明ける。最後まで明けきったら true、割り込まれたら false。
func fade_out(duration: float = 1.0, from: float = NAN) -> bool:
	_screen_held = true
	_apply_transition_look()
	var start: float = from if not is_nan(from) else _current_strength_or(1.0)
	var completed: bool = await _play_fade(start, -1.0, duration)
	# 割り込まれたときは、もう画面の持ち主は別の暗転。表示を消してはいけない。
	if completed:
		circle_dithering.visible = false
		_screen_held = false
	return completed

## ダメージやパリィのときの一瞬の色フラッシュ。暗転と同じ ColorRect を借りる。
## 画面遷移の暗転中は出さない（出すと暗転が途中で明けてしまう）。
func flash_fade(color_rgb: Vector3, alpha: float, duration: float, from: float) -> void:
	if _screen_held:
		return
	circle_dithering_mat.set_shader_parameter("fade_color_rgb", color_rgb)
	circle_dithering_mat.set_shader_parameter("alpha", alpha)
	var completed: bool = await _play_fade(from, -1.0, duration)
	if completed:
		circle_dithering.visible = false
		# 次の暗転に、フラッシュの色や薄さを持ち越さない
		_apply_transition_look()

## 暗転用の色・不透明度に戻す
func _apply_transition_look() -> void:
	circle_dithering_mat.set_shader_parameter("fade_color_rgb", _fade_color)
	circle_dithering_mat.set_shader_parameter("alpha", 1.0)

func _is_fading() -> bool:
	return _fade_tween != null and _fade_tween.is_valid() and _fade_tween.is_running()

func _current_strength_or(default_value: float) -> float:
	if _is_fading():
		return float(circle_dithering_mat.get_shader_parameter("strength"))
	return default_value

## 暗転 Tween を 1 本だけ走らせる共通処理。
## 最後まで動ききったら true、別の _play_fade() に割り込まれたら false。
func _play_fade(from: float, to: float, duration: float) -> bool:
	_fade_generation += 1
	var my_generation := _fade_generation

	var superseded_generation := my_generation - 1
	var had_running := _fade_tween != null and _fade_tween.is_valid()
	if had_running:
		_fade_tween.kill()   # kill() すると finished は二度と来ない

	circle_dithering.visible = true
	circle_dithering_mat.set_shader_parameter("strength", from)
	_fade_tween = create_tween()
	_fade_tween.tween_property(circle_dithering_mat, "shader_parameter/strength", to, duration)
	_fade_tween.finished.connect(func(): _fade_ended.emit(my_generation))

	# 止めた Tween を await していた側を起こす（起きた側は自分が古いと気づいて false を返す）
	if had_running:
		_fade_ended.emit(superseded_generation)

	while true:
		var ended: int = await _fade_ended
		if _fade_generation != my_generation:
			return false   # 自分より新しい暗転が始まった
		if ended == my_generation:
			return true
	return false

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

	var base: Vector2 = cam.offset - shake_offset

	if shake_strength > 0.0:
		shake_offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
	else:
		shake_offset = Vector2.ZERO

	cam.offset = base + shake_offset
