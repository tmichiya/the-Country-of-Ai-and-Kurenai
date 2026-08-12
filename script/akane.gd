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
var MOVE_SPEED: float = 1.0
var move_speed: float = MOVE_SPEED
var movement_dash_timer: float = 0.0
var movement_state: MovementState = MovementState.NONE
var movement_state_dash_strength: float = 0
var attack_instance: Node2D = null

@export var player: CharacterBody2D
@export var paint_layer: Node2D
const attack_karatake_scene: PackedScene = preload("res://scene/akane/attack_karatake.tscn")
const attack_onagi_scene: PackedScene = preload("res://scene/akane/attack_onagi.tscn")

func attack(attack_name: String) -> void:
	if attack_name == "karatake":
		attack_instance = attack_karatake_scene.instantiate()
	elif attack_name == "onagi":
		attack_instance = attack_onagi_scene.instantiate()

	add_child(attack_instance)
	attack_instance.global_position = global_position
	attack_instance.paint_layer = paint_layer
	attack_instance.attack_finished.connect(_on_attack_finished)

	if attack_instance.has_signal("parried"):
		attack_instance.parried.connect(parried)

	state = State.ATTACK

	if attack_name == "onagi":
		movement_state = MovementState.DASH
		dash(0.5, 200.0)

func _on_attack_finished() -> void:
	attack_instance = null
	state = State.IDLE
	state_timer = randf_range(1.0, 3.0)

func is_telegraphing() -> bool:
	if attack_instance and attack_instance.has_method("is_playing_telegraph_animation"):
		return attack_instance.is_playing_telegraph_animation()
	return false

func take_damage(amount: int) -> void:
	print("Akane took %d damage!" % amount)

func dash(length: float, strength: float) -> void:
	movement_state = MovementState.DASH
	movement_dash_timer = length
	movement_state_dash_strength = strength

func parried(uv: Vector2) -> void:
	if attack_instance and attack_instance.has_method("switch_is_telegraphing_to") and attack_instance.is_playing_telegraph_animation():
		attack_instance.switch_is_telegraphing_to(false)


	dash(0.5, -200.0)
	Effects.slowmotion(0, 0.12)
	Effects.shake(3.5)

	print("position: %s" % position)
	Effects.flash_impact(Effects.FLASH_WHITE, 1.0, 0.3, uv)

func _physics_process(delta: float) -> void:
	if state == State.IDLE:
		if player:
			var direction = Vector2(player.position.x - position.x, player.position.y - position.y).normalized()
			rotation = direction.angle()
		
		if state_timer > 0.0:
			state_timer -= delta
		else:
			var random_attack = attacks[randi() % attacks.size()]

			# テスト用
			random_attack = attacks[1]

			attack(random_attack)
			state_timer = randf_range(1.0, 3.0)

	# 足元が敵色なら鈍足
	var color_at_feet = paint_layer.get_owner_at(global_position)
	if color_at_feet == paint_layer.AI:
		move_speed = MOVE_SPEED * 0.5
	elif color_at_feet == paint_layer.KURENAI:
		move_speed = MOVE_SPEED * 1.2
	else:
		move_speed = MOVE_SPEED

	if movement_state == MovementState.DASH:
		movement_dash_timer -= delta
		if movement_dash_timer <= 0:
			movement_state = MovementState.NONE
			movement_state_dash_strength = 0
			velocity = Vector2.ZERO
		else:
			velocity = Vector2(cos(rotation), sin(rotation)) * movement_state_dash_strength * movement_dash_timer * move_speed

	move_and_slide()
