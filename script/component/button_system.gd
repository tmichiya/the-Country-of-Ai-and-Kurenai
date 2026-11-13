extends Control

signal button_pressed(control: Control)

@export var selected_style_box_texture: StyleBoxTexture
@export var unselected_style_box_texture: StyleBoxTexture
@export var selected_font_color: Color = Color(1, 1, 1)
@export var unselected_font_color: Color = Color(0.5, 0.5, 0.5)

## Frame（余白 0 の MarginContainer）の中に、見た目の枠（PanelContainer）と当たり判定（Button）を並べて重ねる。
## Button を PanelContainer の子にすると枠の StyleBox の余白ぶん縮むので、兄弟にして同じ大きさにしている。
@onready var start_button: Button = $Frame/Button
@onready var panel_container: PanelContainer = $Frame/PanelContainer
@onready var label: Label = $Frame/PanelContainer/MarginContainer/Label

func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)
	start_button.focus_entered.connect(_selected)
	start_button.focus_exited.connect(_unselected)
	start_button.mouse_entered.connect(_selected)
	start_button.mouse_exited.connect(_unselected)

	_reset()

## 中の Button を返す。外からは中の構造（パス）に依存せず、これで取る。
func get_button() -> Button:
	return start_button

## 外部からキーボード／パッドのフォーカスを当てる。
## （ポーズメニューを開いた瞬間に最初の項目を選択状態にするため）
func grab_button_focus() -> void:
	start_button.grab_focus()

func _reset() -> void:
	panel_container.add_theme_stylebox_override("panel", unselected_style_box_texture)
	label.add_theme_color_override("font_color", unselected_font_color)

func _on_start_button_pressed() -> void:
	button_pressed.emit(self)

func _selected() -> void:
	panel_container.add_theme_stylebox_override("panel", selected_style_box_texture)
	label.add_theme_color_override("font_color", selected_font_color)

func _unselected() -> void:
	panel_container.add_theme_stylebox_override("panel", unselected_style_box_texture)
	label.add_theme_color_override("font_color", unselected_font_color)
