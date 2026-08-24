extends CharacterBody2D

enum State {
	MOVE,
	DASH
}

@export var MOVE_SPEED: float = 100.0
@export var MANA: float = 100.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.0
@export var dash_speed: float = 400.0
@export var rolling_duration: float = 0.1
@export var paint_layer: Node2D

@onready var mana_component: ManaComponent = $ManaComponent
@onready var animated_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var visual: Node2D = $Visual

var state: State = State.MOVE
var move_speed: float = MOVE_SPEED
var normalized_input: Vector2 = Vector2.ZERO
var anim_dir: String = "down"
var dash_dir: Vector2 = Vector2.ZERO
var attack_instance: Node2D = null
var mana: float = MANA
var dash_timer: float = 0.0
var dash_cd_timer: float = 0.0

const attack_dash_scene: PackedScene = preload("res://scene/player/attack_dash_player.tscn")
const attack_parry_scene: PackedScene = preload("res://scene/player/attack_parry.tscn")
const attack_rolling_scene: PackedScene = preload("res://scene/player/attack_rolling.tscn")

func reset() -> void:
	state = State.MOVE
	move_speed = MOVE_SPEED
	dash_timer = 0.0
	dash_cd_timer = 0.0
	mana_component.reset()
	if attack_instance:
		attack_instance.queue_free()
		attack_instance = null
	_set_position()

func set_process_to(active: bool) -> void:
	set_process_input(active)
	set_physics_process(active)

func _set_position() -> void:
	var start_marker = get_parent().get_node_or_null("PlayerStartMarker") as Marker2D
	if start_marker:
		global_position = start_marker.global_position
	else:
		push_error("PlayerStartMarker is missing in the scene.")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dash") and state == State.MOVE and dash_cd_timer <= 0:		
		if not mana_component.spend(10.0):
			return
		dash_timer = dash_duration
		dash_cd_timer = dash_cooldown
		dash_dir = normalized_input if normalized_input != Vector2.ZERO else (get_global_mouse_position() - global_position).normalized()

		attack_instance = attack_dash_scene.instantiate()
		add_child(attack_instance)
		attack_instance.global_position = global_position
		
		state = State.DASH

	if event.is_action_pressed("rolling") and state == State.MOVE:
		if not mana_component.spend(5.0):
			return
		dash_timer = rolling_duration
		dash_dir = normalized_input if normalized_input != Vector2.ZERO else (get_global_mouse_position() - global_position).normalized()

		attack_instance = attack_rolling_scene.instantiate()
		add_child(attack_instance)
		attack_instance.global_position = global_position

		state = State.DASH

	if event.is_action_pressed("parry") and state == State.MOVE:
		if not mana_component.spend(5.0):
			return
		attack_instance = attack_parry_scene.instantiate()
		add_child(attack_instance)
		attack_instance.global_position = global_position
		if attack_instance.has_method("parried"):
			attack_instance.parried.connect(_on_attack_finished)
		attack_instance.attack_finished.connect(_on_attack_finished)
		attack_instance.rotation = global_position.angle_to_point(get_global_mouse_position())

func _on_attack_finished() -> void:
	if attack_instance:
		attack_instance = null
		state = State.MOVE

func timer_control(delta: float) -> void:
	if dash_cd_timer > 0:
		dash_cd_timer -= delta
	if dash_timer > 0:
		dash_timer -= delta

func _on_died() -> void:
	print("Player has died due to mana depletion.")

func _on_dialogue_started(_t: String) -> void:
	_set_sprite(Vector2.ZERO)
	set_process_to(false)

func _on_dialogue_finished(_t: String) -> void:
	set_process_to(true)

func _set_sprite(input_vector: Vector2) -> void:
	var direction = input_vector.angle()
	if input_vector == Vector2.ZERO:
		if anim_dir == "down":
			animated_sprite.play("down_idle")
		elif anim_dir == "up":
			animated_sprite.play("up_idle")
		elif anim_dir == "left":
			animated_sprite.play("left_idle")
		elif anim_dir == "right":
			animated_sprite.play("right_idle")
	else:
		if direction >= -PI/4 and direction < PI/4:
			animated_sprite.play("right_walk")
			anim_dir = "right"
		elif direction >= PI/4 and direction < 3*PI/4:
			animated_sprite.play("down_walk")
			anim_dir = "down"
		elif direction >= -3*PI/4 and direction < -PI/4:
			animated_sprite.play("up_walk")
			anim_dir = "up"
		else:
			animated_sprite.play("left_walk")
			anim_dir = "left"

func _ready() -> void:
	state = State.MOVE
	mana_component.depleted.connect(_on_died)
	Dialogue.started.connect(_on_dialogue_started)
	Dialogue.finished.connect(_on_dialogue_finished)

func _physics_process(delta: float) -> void:
	timer_control(delta)

	if(state == State.DASH):
		velocity = dash_dir * dash_speed

		if (dash_timer <= 0):
			if attack_instance:
				attack_instance.queue_free()
			state = State.MOVE
	
	if (state == State.MOVE):
		var input_vector = Input.get_vector("left", "right", "up", "down")
		velocity = input_vector * move_speed
		normalized_input = input_vector.normalized() if input_vector != Vector2.ZERO else Vector2.ZERO
		_set_sprite(input_vector)

	# 足元が敵色なら鈍足
	if paint_layer:
		var color_at_feet = paint_layer.get_owner_at(global_position)
		if color_at_feet == paint_layer.KURENAI:
			move_speed = MOVE_SPEED * 0.5
			mana_component.spend(2.0 * delta)
		elif color_at_feet == paint_layer.AI:
			move_speed = MOVE_SPEED * 1.2
			mana_component.restore(6.0 * delta)
		else:
			move_speed = MOVE_SPEED

	move_and_slide()
