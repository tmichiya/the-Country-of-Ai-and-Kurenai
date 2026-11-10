class_name DefeatBanner
extends Control
## 撃破の宣言（大きな一文字＋小さな一行）を中央に出して消す。スロー中でも実時間で動く。

@onready var _main_label: Label = %MainLabel
@onready var _sub_label: Label = %SubLabel

var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide_immediately()


## 文字を fade_in 秒で出し、hold 秒見せて、fade_out 秒で消す。消え終わるまで await できる。
func play(main_text: String, sub_text: String, hold: float = 1.2, fade_in: float = 0.2, fade_out: float = 0.5) -> void:
	_kill_tween()
	_main_label.text = main_text
	_sub_label.text = sub_text
	_sub_label.visible = sub_text != ""
	modulate.a = 0.0
	visible = true

	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_property(self, "modulate:a", 1.0, fade_in) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold)
	_tween.tween_property(self, "modulate:a", 0.0, fade_out) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(hide)
	await get_tree().create_timer(fade_in + hold + fade_out, false, false, true).timeout


## 演出の中断用。その場で消す。
func hide_immediately() -> void:
	_kill_tween()
	modulate.a = 0.0
	visible = false


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
