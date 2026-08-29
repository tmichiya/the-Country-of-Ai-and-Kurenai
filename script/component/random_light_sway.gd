extends PointLight2D

@export var light_energy_pivot: float = 1.0
@export var speed: float = 0.0015

var initial_position: Vector2

var energy_sin: float = 1.0
var SWAY_DURATION: float = 1.0
var sway_duration: float = SWAY_DURATION

func _ready() -> void:
	initial_position = position

func _process(delta: float) -> void:
	energy_sin = sin(Time.get_ticks_msec() * speed) * 0.1 + light_energy_pivot
	energy = energy_sin

	sway_duration -= delta
	if sway_duration <= 0.0:
		sway_duration = SWAY_DURATION
		position = initial_position + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))