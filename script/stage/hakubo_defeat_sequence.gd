class_name HakuboDefeatSequence
extends Node
## 薄暮を撃破したときの演出（止まる → 無音 → 藍が広がる → 文字 → 鳥の声）を 1 か所で流す。
## battle_manager が play() を await し、終わってから戦闘後の会話へ進む。
## 時刻はすべて「撃破の瞬間からの実時間（秒）」。スローやポーズの影響を受けない。

## play() に渡す材料。
class Context:
	var hakubo: CharacterBody2D
	var player: CharacterBody2D
	var paint_layer: Node2D
	var ui_manager: CanvasLayer
	## いま見えている時間帯の CanvasModulate
	var lighting: CanvasModulate
	## 何形態目か（0 始まり）。戦闘開始時の周回番号を渡す。
	var form: int = 0

@export var letterbox: Letterbox
@export var banner: DefeatBanner

@export_group("止め・スロー")
@export var freeze_duration: float = 0.12
@export var slow_scale: float = 0.3
@export var slow_duration: float = 0.4
@export var impact_shake: float = 5.0
@export var flash_duration: float = 0.6

@export_group("カメラ・黒帯")
@export var camera_zoom_mult: float = 1.3
@export var camera_zoom_in_time: float = 0.4
@export var camera_zoom_out_time: float = 0.6
@export var letterbox_time: float = 0.35

@export_group("HUD")
@export var hud_break_at: float = 0.3
@export var hud_fade_time: float = 0.5

@export_group("藍の波")
@export var ink_wave_at: float = 1.2
@export var ink_wave_radii: PackedFloat32Array = [60.0, 120.0, 200.0, 300.0]
@export var ink_wave_interval: float = 0.1
@export var ink_wave_shake: float = 3.0

@export_group("呪いが薄れる（最終形態だけ）")
## この形態のときだけ、藍の波と一緒に黒さを少し引かせる。本当に抜けるのは会話の中。
@export var final_form: int = 2
@export var final_form_corruption: float = 0.6
@export var final_form_corruption_time: float = 1.0

@export_group("文字")
@export var banner_at: float = 2.0
@export var banner_hold: float = 1.2
@export var banner_main_text: String = "討"
## 形態ごとの小さな一行
@export var banner_sub_texts: PackedStringArray = ["薄暮 撃破", "薄暮 撃破", "呪縛 断絶"]

@export_group("鳥の声・光")
@export var birds_at: float = 2.8
@export var bird_count_min: int = 1
@export var bird_count_max: int = 2
@export var light_time: float = 1.5
## 形態ごとに、時間帯の色をどの色へ寄せるか
@export var light_targets: Array[Color] = [Color.WHITE, Color.WHITE, Color(0.91, 0.89908, 0.8008, 1.0)]
## 形態ごとに、どれだけ寄せるか（0〜1）
@export var light_weights: PackedFloat32Array = [0.15, 0.15, 0.5]

@export_group("終わり")
@export var end_at: float = 3.5
@export var bgm_fade_in: float = 2.0

## play() / reset() のたびに増える。await から戻ったとき自分がまだ最新かを確かめる。
var _generation: int = 0
## play() の開始からの経過（予定）時刻。_wait_until() が使う。
var _elapsed: float = 0.0
var _light_tween: Tween

var _saved_light: CanvasModulate = null
var _saved_light_color: Color = Color.WHITE
var _saved_zoom: Vector2 = Vector2.ONE
var _ui_manager: CanvasLayer = null


## 撃破演出を最後まで流す。最後まで流れたら true、途中で reset() されたら false。
func play(ctx: Context) -> bool:
	_generation += 1
	var gen := _generation
	_elapsed = 0.0
	_ui_manager = ctx.ui_manager
	_save_lighting(ctx.lighting)

	# 0.00 完全に止める＋藍のフラッシュ＋決めの音
	Effects.set_time_scale_for(0.0, freeze_duration, true, true)
	Effects.flash_impact(Effects.FLASH_AI, 1.0, flash_duration, _world_to_uv(ctx.hakubo), true)
	Effects.shake(impact_shake)
	AudioManager.play_se("hakubo_defeat")
	AudioManager.play_se("ink_splash_large")
	if not await _wait_until(freeze_duration, gen):
		return false

	# 0.12 無音にしてスロー。薄暮に寄って黒帯を出す
	AudioManager.stop_bgm(0.05)
	Effects.set_time_scale_for(slow_scale, slow_duration, true, true)
	_focus_camera(ctx.hakubo)
	letterbox.show_bars(letterbox_time)
	if not await _wait_until(hud_break_at, gen):
		return false

	# 0.3 メインのマナバーが砕け、HUD が消える
	ctx.ui_manager.burst_hakubo_main_bar()
	ctx.ui_manager.fade_out_hud(hud_fade_time)
	if not await _wait_until(ink_wave_at, gen):
		return false

	# 1.2 薄暮を中心に藍の波が床へ広がる（最終形態は呪いが少し薄れる）
	if ctx.form == final_form:
		ctx.hakubo.tween_corruption(final_form_corruption, final_form_corruption_time)
	if not await _spread_ink_wave(ctx, gen):
		return false
	if not await _wait_until(banner_at, gen):
		return false

	# 2.0 文字で宣言
	banner.play(banner_main_text, _pick(banner_sub_texts, ctx.form, ""), banner_hold)
	if not await _wait_until(birds_at, gen):
		return false

	# 2.8 静寂の中で鳥の声。時間帯の色を少し明るく
	_play_birds(gen)
	_brighten_lighting(ctx.form)
	if not await _wait_until(end_at, gen):
		return false

	# 3.5 黒帯を引っ込めて終わる
	_release_camera()
	AudioManager.play_bgm(AudioManager.BGM_BATTLE_STAGE, bgm_fade_in, true)
	await letterbox.hide_bars(letterbox_time)
	if gen != _generation:
		return false
	ctx.hakubo.set_process_to(false)
	_cleanup()
	return true


## 走っている演出を打ち切り、演出で変えたものをすべて元に戻す。
## 部屋の入り直し・タイトルへ戻るときに battle_manager から呼ぶ。
func reset() -> void:
	_generation += 1
	_cleanup()
	if _ui_manager:
		_ui_manager.reset_hud_look()
	if is_instance_valid(_saved_light):
		_saved_light.color = _saved_light_color
	_saved_light = null


## 演出のあとに残してはいけないもの（スロー・黒帯・文字・色の Tween）を片付ける。
## 正常終了と中断の両方から呼ぶ。明るくした時間帯の色と消した HUD は、会話のあいだ残すのでここでは戻さない。
func _cleanup() -> void:
	Effects.reset_time_scale()
	if letterbox:
		letterbox.hide_immediately()
	if banner:
		banner.hide_immediately()
	if _light_tween and _light_tween.is_valid():
		_light_tween.kill()
	_light_tween = null


## 撃破の瞬間からの時刻 t（秒）まで待つ。待ったあとも自分が最新なら true。
func _wait_until(t: float, gen: int) -> bool:
	var d := t - _elapsed
	_elapsed = maxf(_elapsed, t)
	if d > 0.0:
		# ポーズ中は止まる／time_scale は無視する
		await get_tree().create_timer(d, false, false, true).timeout
	return gen == _generation


## 半径を広げながら藍で塗り、床に波が広がって見えるようにする。
func _spread_ink_wave(ctx: Context, gen: int) -> bool:
	var center := ctx.hakubo.global_position
	Effects.shake(ink_wave_shake)
	Effects.flash_impact(Effects.FLASH_AI, 0.6, 0.8, _world_to_uv(ctx.hakubo), true)
	AudioManager.play_se("ink_splash_large")
	for r in ink_wave_radii:
		ctx.paint_layer.paint_blob(center, r, ctx.paint_layer.AI)
		if not await _wait_until(_elapsed + ink_wave_interval, gen):
			return false
	return true


## 鳥の声を 1〜数回、少し間をあけて鳴らす。
func _play_birds(gen: int) -> void:
	var count := randi_range(bird_count_min, bird_count_max)
	for i in count:
		if i > 0:
			await get_tree().create_timer(randf_range(0.4, 0.9), false, false, true).timeout
			if gen != _generation:
				return
		AudioManager.play_random_bird_se()


## 薄暮を追うカメラに切り替えて寄る。いまの見た目の倍率から続けて寄るので画面が跳ねない。
func _focus_camera(hakubo: Node2D) -> void:
	if Camera.camera == null:
		return
	_saved_zoom = Camera.camera_zoom_offset
	# BATTLE 状態では距離に応じた倍率が掛かっている。FOLLOW_TARGET では掛からないので、見た目の倍率を引き継ぐ
	var current_zoom := Camera.get_current_zoom_value()
	Camera.camera_zoom_offset = current_zoom
	if not Camera.targets.has("hakubo"):
		Camera.add_target("hakubo", hakubo)
	Camera.set_state(Camera.CameraState.FOLLOW_TARGET)
	Camera.set_current_target("hakubo")
	Camera.set_zoom_value(current_zoom * camera_zoom_mult, camera_zoom_in_time, true)


## 会話用に二人の間を映すカメラへ戻し、倍率を戦闘前の値へ戻す。
func _release_camera() -> void:
	if Camera.camera == null:
		return
	Camera.set_state(Camera.CameraState.AVERAGE_CENTER)
	Camera.set_zoom_value(_saved_zoom, camera_zoom_out_time, true)


## 時間帯の元の色を覚えておく。同じ部屋で 2 回目なら、明るくする前の色を持ち続ける。
func _save_lighting(lighting: CanvasModulate) -> void:
	if lighting == null or lighting == _saved_light:
		return
	_saved_light = lighting
	_saved_light_color = lighting.color


## 時間帯の色を、形態ごとの目標色へ少し寄せる。
func _brighten_lighting(form: int) -> void:
	if not is_instance_valid(_saved_light):
		return
	var target_color: Color = _pick(light_targets, form, Color.WHITE)
	var weight: float = _pick(light_weights, form, 0.0)
	var to := _saved_light_color.lerp(target_color, weight)
	_light_tween = create_tween().set_ignore_time_scale(true)
	_light_tween.tween_property(_saved_light, "color", to, light_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## 形態ごとの配列から値を取り出す。足りなければ最後の要素、空なら fallback。
func _pick(values, form: int, fallback):
	if values.is_empty():
		return fallback
	return values[clampi(form, 0, values.size() - 1)]


func _world_to_uv(node: Node2D) -> Vector2:
	var vp := node.get_viewport()
	var screen_pos := vp.get_canvas_transform() * node.global_position
	return screen_pos / vp.get_visible_rect().size
