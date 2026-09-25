extends Node2D

var is_displaying: bool = false
var display_timer: float = 0.0

var duration: float = 0.5

func _ready() -> void:
	is_displaying = false
	visible = false

func _process(delta: float) -> void:
	display_timer -= delta
	if display_timer <= 0.0:
		is_displaying = false
		visible = false

func display_text(position: Vector2) -> void:
	is_displaying = true
	display_timer = duration
	visible = true
	global_position = position