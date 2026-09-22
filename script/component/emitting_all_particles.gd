extends Node2D

@export var particles : Array[GPUParticles2D] = []

func restart() -> void:
	for particle in particles:
		particle.restart()

func emitting() -> void:
	for particle in particles:
		particle.emitting = true