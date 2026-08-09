extends CharacterBody2D

enum State {
	IDLE,
	ATTACK,
	CHAT
}

var state: State = State.IDLE
var state_timer: float = 1.0
var attack_instance: Node2D = null

@export var player: CharacterBody2D
const attack_karatake_scene: PackedScene = preload("res://scene/Attack_Karatake.tscn")

func attack_karatake() -> void:
	attack_instance = attack_karatake_scene.instantiate()
	add_child(attack_instance)
	attack_instance.global_position = global_position
	attack_instance.attack_finished.connect(_on_attack_finished)

	state = State.ATTACK

func _on_attack_finished() -> void:
	print("Attack finished")
	attack_instance = null
	state = State.IDLE
	state_timer = randf_range(1.0, 3.0)

func _physics_process(delta: float) -> void:
	if state == State.IDLE:
		if player:
			print("Player position: %s" % player.position)
			var direction = Vector2(player.position.x - position.x, player.position.y - position.y).normalized()
			rotation = direction.angle()
			print("Rotation towards player: %s" % rotation)
		
		if state_timer > 0.0:
			state_timer -= delta
		else:
			attack_karatake()
			state_timer = randf_range(1.0, 3.0)

	move_and_slide()
