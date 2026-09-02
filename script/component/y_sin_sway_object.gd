extends Node2D

@export var sway_speed: float = 1.0
@export var sway_amplitude: float = 5.0

var shift: float = 0.0
var default_y_pos: float = 0.0

var offset_val: float = 0.0 
var t: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	default_y_pos = position.y


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	t += delta

	offset_val = sin(t * sway_speed) * sway_amplitude
	position.y = default_y_pos + offset_val

	if t > 2 * PI / sway_speed:
		t -= 2 * PI / sway_speed
