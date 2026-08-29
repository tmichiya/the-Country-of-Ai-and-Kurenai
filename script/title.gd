extends Node2D

func _ready() -> void:
	var button_system: Control = $CanvasLayer/VBoxContainer/Start
	button_system.button_pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	print("Start button pressed in title scene.")
	GameManager.change_scene_to("opening")