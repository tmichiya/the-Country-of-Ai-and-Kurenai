class_name Letterbox
extends Control
## 画面の上下に黒帯を出し入れする（映画の決めカットのような見せ方）。
## show_bars() / hide_bars() は await でき、スロー中でも実時間で動く。

@export var bar_height: float = 34.0
@export var bar_color: Color = Color(0.0, 0.0, 0.0, 1.0)

@onready var _top: ColorRect = $Top
@onready var _bottom: ColorRect = $Bottom

## 0 で帯なし、1 で bar_height いっぱい。
var _ratio: float = 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.color = bar_color
	_bottom.color = bar_color
	_apply_ratio(0.0)


## 帯を duration 秒かけて出す。
func show_bars(duration: float = 0.35) -> void:
	await _animate_to(1.0, duration)


## 帯を duration 秒かけて引っ込める。
func hide_bars(duration: float = 0.35) -> void:
	await _animate_to(0.0, duration)


## 演出の中断用。その場で帯を消す。
func hide_immediately() -> void:
	_kill_tween()
	_apply_ratio(0.0)


func _animate_to(target: float, duration: float) -> void:
	_kill_tween()
	visible = true
	_tween = create_tween().set_ignore_time_scale(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_apply_ratio, _ratio, target, duration)
	# kill() された Tween の finished は来ないので、待つのはタイマーにする（ポーズ中は止まる）
	await get_tree().create_timer(duration, false, false, true).timeout


func _apply_ratio(ratio: float) -> void:
	_ratio = ratio
	var h := bar_height * ratio
	_top.offset_bottom = h
	_bottom.offset_top = -h
	visible = ratio > 0.0


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
