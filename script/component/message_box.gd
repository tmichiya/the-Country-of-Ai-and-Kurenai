class_name MessageBox
extends Node2D
## 文章を 1 枚だけ出し、決定（ui_accept）かクリックで閉じる箱。
## select_box と同じ表示／非表示アニメを使い回している。
##   await message_box.show_message("……")   # 閉じられるまで待つ

signal closed

## 開いた直後の入力を無視する秒数（開くきっかけになった決定キーで即閉じないように）。
const INPUT_GUARD_SECONDS := 0.25

@onready var control: Control = $CanvasLayer/Control
@onready var dim: ColorRect = $CanvasLayer/ColorRect
@onready var text_label: Label = %Label
@onready var close_button: Button = %CloseButton
@onready var animation_player: AnimationPlayer = $CanvasLayer/AnimationPlayer

var _is_open: bool = false
var _opened_at_msec: int = 0


func _ready() -> void:
	control.visible = false
	dim.visible = false
	close_button.pressed.connect(close)


func is_open() -> bool:
	return _is_open


func show_message(text: String) -> void:
	open(text)
	await closed


func open(text: String) -> void:
	text_label.text = text
	_is_open = true
	_opened_at_msec = Time.get_ticks_msec()
	animation_player.play("display_box")
	AudioManager.play_se("next_chat")


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	animation_player.play("hide_box")
	AudioManager.play_se("button_pressed")
	closed.emit()


func _process(_delta: float) -> void:
	if not _is_open or get_tree().paused:
		return
	if Time.get_ticks_msec() - _opened_at_msec < INPUT_GUARD_SECONDS * 1000.0:
		return
	if Input.is_action_just_pressed("ui_accept"):
		close()
