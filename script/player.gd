extends CharacterBody2D

enum State {
	MOVE,
	DASH
}

var state: State = State.MOVE
var move_speed: float = 200.0
var direction: Vector2 = Vector2.ZERO
var dash_dir: Vector2 = Vector2.ZERO
var attack_instance: Node2D = null
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.0
@export var dash_speed: float = 400.0

const attack_dash_scene: PackedScene = preload("res://scene/player/attack_dash.tscn")
const attack_parry_scene: PackedScene = preload("res://scene/player/attack_parry.tscn")

var dash_timer: float = 0.0
var dash_cd_timer: float = 0.0

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dash") and state == State.MOVE and dash_cd_timer <= 0:		
		dash_timer = dash_duration
		dash_cd_timer = dash_cooldown
		dash_dir = direction

		attack_instance = attack_dash_scene.instantiate()
		add_child(attack_instance)
		attack_instance.global_position = global_position
		
		state = State.DASH

	if event.is_action_pressed("parry") and state == State.MOVE:
		attack_instance = attack_parry_scene.instantiate()
		add_child(attack_instance)
		attack_instance.global_position = global_position
		if attack_instance.has_method("parried"):
			attack_instance.parried.connect(_on_attack_finished)
		attack_instance.attack_finished.connect(_on_attack_finished)

func _on_attack_finished() -> void:
	if attack_instance:
		attack_instance = null
		state = State.MOVE

func timer_control(delta: float) -> void:
	if dash_cd_timer > 0:
		dash_cd_timer -= delta
	if dash_timer > 0:
		dash_timer -= delta

func take_damage(amount: int) -> void:
	print("Player took %d damage!" % amount)

func _ready() -> void:
	state = State.MOVE

func _physics_process(delta: float) -> void:
	timer_control(delta)

	if(state == State.DASH):
		velocity = dash_dir * dash_speed

	if (dash_timer <= 0 and state == State.DASH):
		if attack_instance:
			attack_instance.queue_free()
		state = State.MOVE
	
	if (state == State.MOVE):
		move_speed = 200.0
		velocity = Input.get_vector("left", "right", "up", "down") * move_speed

		var mouse_pos = get_global_mouse_position()
		direction = (mouse_pos - position).normalized()
		rotation = direction.angle()

	move_and_slide()
