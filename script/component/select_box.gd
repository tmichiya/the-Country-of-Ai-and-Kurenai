extends Node2D

signal left_button_pressed
signal right_button_pressed

@onready var control : Control = $CanvasLayer/Control
@onready var text_label: Label = $CanvasLayer/Control/Text/PanelContainer/MarginContainer/Label
@onready var animation_player: AnimationPlayer = $CanvasLayer/AnimationPlayer

@onready var left_control: Control = $CanvasLayer/Control/Left
@onready var right_control: Control = $CanvasLayer/Control/Right
@onready var left_button: Button = $CanvasLayer/Control/Left/PanelContainer/Button
@onready var right_button: Button = $CanvasLayer/Control/Right/PanelContainer/Button

@onready var left_button_label: Label = $CanvasLayer/Control/Left/PanelContainer/MarginContainer/Label
@onready var right_button_label: Label = $CanvasLayer/Control/Right/PanelContainer/MarginContainer/Label

func _ready() -> void:
	control.visible = false

	left_button.pressed.connect(_on_left_button_pressed)
	right_button.pressed.connect(_on_right_button_pressed)

func set_text(text: String) -> void:
	text_label.text = text

func set_left_button_text(text: String) -> void:
	left_button_label.text = text

func set_right_button_text(text: String) -> void:
	right_button_label.text = text

func display_box() -> void:
	control.visible = true
	animation_player.play("display_select_box")

func hide_box() -> void:
	animation_player.play("hide_select_box")

func _on_left_button_pressed() -> void:
	left_button_pressed.emit()

	hide_box()

func _on_right_button_pressed() -> void:
	right_button_pressed.emit()

	hide_box()
