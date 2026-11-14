class_name EntityOutlineAnimation
extends AnimatedSprite2D

@export var base_animated_sprite2d : AnimatedSprite2D
@export var fade_duration: float = 0.2

var playing_anim : String = ""

## シーンで設定した modulate.a を「表示中の濃さ」として覚えておく
var _shown_alpha: float = 1.0
var _fade_tween: Tween

## set_outline_visible() で最後に頼まれた表示状態（OutlineDisplayZone などからの「ふだんの」状態）
var _requested_shown: bool = false
## flash() 中は true。フラッシュが終わったら _requested_shown に戻す
var _is_flashing: bool = false
## flash() を連続で呼んだとき、古い flash の後始末を無効にするための世代番号
var _flash_generation: int = 0

func _ready() -> void:
	if not base_animated_sprite2d:
		print("EntityOutlineAnimation: No base animated sprite2d assigned to entity_outline_animation.gd")
	_shown_alpha = modulate.a
	modulate.a = 0.0


func _process(delta: float) -> void:
	var current_animation = base_animated_sprite2d.animation

	if current_animation != playing_anim and current_animation != &"reset":
		playing_anim = current_animation
		play(playing_anim + "_outline")


func set_outline_visible(shown: bool) -> void:
	_requested_shown = shown
	# フラッシュ中は上書きしない。終わったときに、ここで覚えた状態へ戻る
	if _is_flashing:
		return
	_fade_to(_shown_alpha if shown else 0.0)


## 一瞬だけアウトラインを出す（パリィ成功など）。
## すぐに表示し、hold_time 秒後に set_outline_visible() で「ふだんの」状態へ戻す。
## そのため OutlineDisplayZone の中にいるときは、フラッシュのあとも表示されたままになる。
func flash(hold_time: float = 0.2) -> void:
	_flash_generation += 1
	var generation := _flash_generation
	_is_flashing = true
	if _fade_tween:
		_fade_tween.kill()
	modulate.a = _shown_alpha

	# パリィのスロー（time_scale）を無視して実時間で計る。ポーズ中は止まる。
	await get_tree().create_timer(hold_time, false, false, true).timeout
	if generation != _flash_generation or not is_inside_tree():
		return
	_is_flashing = false
	set_outline_visible(_requested_shown)


func hide_immediately() -> void:
	_flash_generation += 1   # 走っているフラッシュの後始末を無効にする
	_is_flashing = false
	_requested_shown = false
	if _fade_tween:
		_fade_tween.kill()
	modulate.a = 0.0


func _fade_to(target_alpha: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	## 途中で反転しても同じ速さで動くよう、残りの距離に比例させる
	var duration := absf(target_alpha - modulate.a) / maxf(_shown_alpha, 0.001) * fade_duration
	## パリィで time_scale = 0 になっても止まらないようにする
	_fade_tween = create_tween().set_ignore_time_scale(true)
	_fade_tween.tween_property(self, "modulate:a", target_alpha, duration)
