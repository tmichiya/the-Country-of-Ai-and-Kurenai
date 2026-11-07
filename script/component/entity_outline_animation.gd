class_name EntityOutlineAnimation
extends AnimatedSprite2D

@export var base_animated_sprite2d : AnimatedSprite2D
@export var fade_duration: float = 0.2

var playing_anim : String = ""

## シーンで設定した modulate.a を「表示中の濃さ」として覚えておく
var _shown_alpha: float = 1.0
var _fade_tween: Tween

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
	_fade_to(_shown_alpha if shown else 0.0)


func hide_immediately() -> void:
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
