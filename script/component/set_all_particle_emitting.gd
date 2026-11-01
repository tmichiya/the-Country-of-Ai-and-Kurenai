extends Node

## target_particles に登録された GPUParticles2D の emitting を一括で切り替える
## 基本は explosion が設定されていない通常の GPUParticles2D を対象とする
## explosion の場合は emitting_all_particles を使用

@export var target_particles: Array[GPUParticles2D] = []

func set_emitting(emitting: bool) -> void:
	for particle in target_particles:
		particle.emitting = emitting