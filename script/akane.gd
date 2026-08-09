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
const attack_karatake_scene: PackedScene = preload("res://scene/akane/attack_karatake.tscn")

func attack_karatake() -> void:
	attack_instance = attack_karatake_scene.instantiate()
	add_child(attack_instance)
	attack_instance.global_position = global_position
	attack_instance.attack_finished.connect(_on_attack_finished)

	state = State.ATTACK

func _on_attack_finished() -> void:
	attack_instance = null
	state = State.IDLE
	state_timer = randf_range(1.0, 3.0)

func is_telegraphing() -> bool:

	print("Checking if attack_instance is telegraphing: %s" % (attack_instance != null and attack_instance.has_method("is_playing_telegraph_animation")))
	if attack_instance and attack_instance.has_method("is_playing_telegraph_animation"):
		return attack_instance.is_playing_telegraph_animation()
	return false

func take_damage(amount: int) -> void:
	print("Akane took %d damage!" % amount)

func _physics_process(delta: float) -> void:
	if state == State.IDLE:
		if player:
			var direction = Vector2(player.position.x - position.x, player.position.y - position.y).normalized()
			rotation = direction.angle()
		
		if state_timer > 0.0:
			state_timer -= delta
		else:
			attack_karatake()
			state_timer = randf_range(1.0, 3.0)

	move_and_slide()
