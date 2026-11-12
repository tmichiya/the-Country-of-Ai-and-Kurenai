extends Control
## 音量設定パネル。タイトルとポーズメニューに同じシーンを置いて使う。
## 持ち主は open() で開き、closed を受け取ってフォーカスを自分のボタンに戻す。

signal closed

const PREVIEW_SE := "bell_1"
## バーを動かし続けたときに試聴音が連打されないよう、最低この間隔をあける
const PREVIEW_INTERVAL_MSEC := 120

@onready var bgm_slider: HSlider = %BgmSlider
@onready var se_slider: HSlider = %SeSlider
@onready var bgm_value_label: Label = %BgmValue
@onready var se_value_label: Label = %SeValue
@onready var back_button: Control = %Back
@onready var back_inner_button: Button = %Back.get_button()

var _last_preview_msec: int = -PREVIEW_INTERVAL_MSEC

## マウスに反応する操作対象（スライダーと戻るボタン）
var _mouse_targets: Array[Control] = []
## ドラッグ中だけ一時的に変えた mouse_filter の元の値（Control → MouseFilter）
var _saved_mouse_filters: Dictionary = {}


func _ready() -> void:
	visible = false
	bgm_slider.value_changed.connect(_on_bgm_changed)
	se_slider.value_changed.connect(_on_se_changed)
	back_button.button_pressed.connect(_on_back_pressed)
	var focus_order: Array[Control] = [bgm_slider, se_slider, back_inner_button]
	_link_focus(focus_order)

	_mouse_targets = focus_order
	for slider: HSlider in [bgm_slider, se_slider]:
		slider.drag_started.connect(_on_slider_drag_started.bind(slider))
		slider.drag_ended.connect(_on_slider_drag_ended)


func is_open() -> bool:
	return visible


func open() -> void:
	# set_value_no_signal: 表示を合わせるだけで、value_changed（試聴音）を出さない
	bgm_slider.set_value_no_signal(GameSettings.bgm_volume)
	se_slider.set_value_no_signal(GameSettings.se_volume)
	_update_value_labels()
	visible = true
	bgm_slider.grab_focus()


func close() -> void:
	if not visible:
		return
	_restore_mouse_targets()
	visible = false
	# バーを動かすたびではなく、閉じるときに 1 回だけ書き込む
	GameSettings.save_settings()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		# 子のほうが親より先に入力を受け取るので、ここで止めればポーズメニューやタイトルには届かない
		get_viewport().set_input_as_handled()
		AudioManager.play_se("button_pressed")
		close()


func _on_bgm_changed(value: float) -> void:
	GameSettings.set_bgm_volume(value)
	_update_value_labels()


func _on_se_changed(value: float) -> void:
	GameSettings.set_se_volume(value)
	_update_value_labels()
	var now := Time.get_ticks_msec()
	if now - _last_preview_msec >= PREVIEW_INTERVAL_MSEC:
		_last_preview_msec = now
		AudioManager.play_se(PREVIEW_SE)


## スライダーを掴んでいる間は、ほかの操作対象をマウスから見えなくする。
## 掴んだままカーソルが別のバーやボタンに重なっても、そちらがハイライトしないようにするため。
func _on_slider_drag_started(dragging: HSlider) -> void:
	_restore_mouse_targets()
	for c in _mouse_targets:
		if c == dragging:
			continue
		_saved_mouse_filters[c] = c.mouse_filter
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_slider_drag_ended(_value_changed: bool) -> void:
	_restore_mouse_targets()


## ドラッグ中に変えた mouse_filter を元に戻す。
func _restore_mouse_targets() -> void:
	for c: Control in _saved_mouse_filters:
		if is_instance_valid(c):
			c.mouse_filter = _saved_mouse_filters[c]
	_saved_mouse_filters.clear()


func _on_back_pressed(_button: Control) -> void:
	AudioManager.play_se("button_pressed")
	close()


func _update_value_labels() -> void:
	bgm_value_label.text = "%d%%" % roundi(bgm_slider.value * 100.0)
	se_value_label.text = "%d%%" % roundi(se_slider.value * 100.0)


## パネルが開いているあいだ、上下のフォーカス移動がパネルの外（後ろのボタン）へ抜けないように輪にする。
func _link_focus(order: Array[Control]) -> void:
	var n := order.size()
	for i in n:
		var c := order[i]
		var prev_path := c.get_path_to(order[(i - 1 + n) % n])
		var next_path := c.get_path_to(order[(i + 1) % n])
		c.focus_neighbor_top = prev_path
		c.focus_neighbor_bottom = next_path
		c.focus_previous = prev_path
		c.focus_next = next_path
	# 左右はスライダーの値の操作に使うので、ボタンだけは左右で外へ出ないようにする
	var self_path := back_inner_button.get_path_to(back_inner_button)
	back_inner_button.focus_neighbor_left = self_path
	back_inner_button.focus_neighbor_right = self_path
