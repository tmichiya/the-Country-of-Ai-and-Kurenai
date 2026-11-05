@tool
class_name InputHint
extends HBoxContainer
## 操作アイコン＋説明文の 1 組。アイコンが切り替わったら枠の幅も合わせ直す。

@export var action: StringName = &"":
	set(value):
		action = value
		_apply()

@export var text: String = "":
	set(value):
		text = value
		_apply()

@export var text_color: Color = Color(0.96, 0.95, 0.92, 1.0):
	set(value):
		text_color = value
		_apply()

@onready var _slot: Control = $PromptSlot
@onready var _prompt: InputPrompt = $PromptSlot/InputPrompt
@onready var _label: Label = $Label


func _ready() -> void:
	_prompt.texture_changed.connect(_fit_slot)
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	_slot.visible = action != &""
	if action != &"":
		_prompt.action = action
	_label.text = text
	_label.visible = text != ""
	_label.add_theme_color_override("font_color", text_color)
	_fit_slot()


func _fit_slot() -> void:
	var icon_size := Vector2.ZERO
	if _prompt.texture:
		icon_size = (_prompt.texture.get_size() * _prompt.scale.abs()).ceil()
	_slot.custom_minimum_size = icon_size
	_prompt.position = icon_size * 0.5
