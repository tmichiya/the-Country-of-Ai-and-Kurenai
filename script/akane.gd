extends CharacterBody2D

enum State {
	IDLE,
	ATTACK,
	CHAT,
	STUNNED
}

enum MovementState {
	NONE,
	DASH
}

var attacks: Array = ["karatake", "onagi"]

var state: State = State.IDLE
var state_timer: float = 1.0
var movement_dash_timer: float = 0.0
var movement_state: MovementState = MovementState.NONE
var movement_state_dash_strength: float = 0
var attack_instance: Node2D = null

@export var player: CharacterBody2D
const attack_karatake_scene: PackedScene = preload("res://scene/akane/attack_karatake.tscn")
const attack_onagi_scene: PackedScene = preload("res://scene/akane/attack_onagi.tscn")

func attack(attack_name: String) -> void:
	if attack_name == "karatake":
		attack_instance = attack_karatake_scene.instantiate()
	elif attack_name == "onagi":
		attack_instance = attack_onagi_scene.instantiate()

	add_child(attack_instance)
	attack_instance.global_position = global_position
	attack_instance.attack_finished.connect(_on_attack_finished)

	state = State.ATTACK

	if attack_name == "onagi":
		movement_state = MovementState.DASH
		movement_dash_timer = 0.5
		movement_state_dash_strength = 200

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
			var random_attack = attacks[randi() % attacks.size()]
			attack(random_attack)
			state_timer = randf_range(1.0, 3.0)

	if movement_state == MovementState.DASH:
		movement_dash_timer -= delta
		if movement_dash_timer <= 0:
			movement_state = MovementState.NONE
			movement_state_dash_strength = 0
			velocity = Vector2.ZERO
		else:
			velocity = Vector2(cos(rotation), sin(rotation)) * movement_state_dash_strength * movement_dash_timer

	move_and_slide()
