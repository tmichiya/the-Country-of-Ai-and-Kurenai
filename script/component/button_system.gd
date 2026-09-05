extends Control

signal button_pressed

@export var selected_style_box_texture: StyleBoxTexture
@export var unselected_style_box_texture: StyleBoxTexture
@export var selected_font_color: Color = Color(1, 1, 1)
@export var unselected_font_color: Color = Color(0.5, 0.5, 0.5)

@onready var start_button: Button = $PanelContainer/Button
@onready var panel_container: PanelContainer = $PanelContainer
@onready var label: Label = $PanelContainer/MarginContainer/Label

func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)
	start_button.focus_entered.connect(_selected)
	start_button.focus_exited.connect(_unselected)
	start_button.mouse_entered.connect(_selected)
	start_button.mouse_exited.connect(_unselected)

	_reset()

func _process(delta: float) -> void:
	pass

## 外部からキーボード／パッドのフォーカスを当てる。
## （ポーズメニューを開いた瞬間に最初の項目を選択状態にするため）
func grab_button_focus() -> void:
	start_button.grab_focus()

func _reset() -> void:
	panel_container.add_theme_stylebox_override("panel", unselected_style_box_texture)
	label.add_theme_color_override("font_color", unselected_font_color)

func _on_start_button_pressed() -> void:
	button_pressed.emit()

func _selected() -> void:
	panel_container.add_theme_stylebox_override("panel", selected_style_box_texture)
	label.add_theme_color_override("font_color", selected_font_color)

func _unselected() -> void:
	panel_container.add_theme_stylebox_override("panel", unselected_style_box_texture)
	label.add_theme_color_override("font_color", unselected_font_color)
