extends VBoxContainer

signal button_pressed(button: Control)

@export var button_controls: Array[Control]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for button in button_controls:
		button.button_pressed.connect(_on_button_pressed)

func _on_button_pressed(button: Control) -> void:
	button_pressed.emit(button)
