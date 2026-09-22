extends Node2D

@export var emitting_particles_components : Array[Node2D] = []

var _next = 0
var _components_size = 0

func _ready() -> void:
	_next = 0
	_components_size = emitting_particles_components.size()

func play_particle() -> void:
	var component = emitting_particles_components[_next]
	component.restart()
	component.emitting()
	_next += (_next + 1) % _components_size
