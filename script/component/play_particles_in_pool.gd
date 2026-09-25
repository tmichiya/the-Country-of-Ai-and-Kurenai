extends Node2D

@export var emitting_particles_components : Array[Node2D] = []

var _next = 0
var _components_size = 0

func _ready() -> void:
	_next = 0
	_components_size = emitting_particles_components.size()

func play_particle(direction: Vector2 = Vector2(0, 0)) -> void:
	var component = emitting_particles_components[_next]

	if not direction.is_equal_approx(Vector2(0, 0)):
		component.rotation = direction.angle()
		print("play_particle: direction = ", direction, ", angle = ", component.rotation)
	component.restart()
	component.emitting()

	print("_next = ", _next, ", _components_size = ", _components_size)

	_next = ((_next + 1) % _components_size)
