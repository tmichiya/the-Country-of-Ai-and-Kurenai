extends Control

@export var sway_speed: float = 1.0
@export var sway_amplitude: float = 5.0

var shift: float = 0.0
var screen_y_pos: float = 0.0
var screen_y_size: float = 0.0

var offset_val: float = 0.0 
var t: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	offset_transform_enabled = true

	screen_y_pos = get_viewport_transform().get_origin().y
	screen_y_size = get_viewport_rect().size.y

	shift = screen_y_pos / screen_y_size * PI * 0.5


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	t += delta

	offset_val = sin(shift + t * sway_speed) * sway_amplitude
	offset_transform_position.y = offset_val

	if t > 2 * PI / sway_speed:
		t -= 2 * PI / sway_speed
