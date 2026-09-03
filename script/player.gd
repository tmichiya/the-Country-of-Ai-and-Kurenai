extends CharacterBody2D

signal dash_started

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

@onready var attack_visual_anim: AnimationPlayer = $AttackVisual/AnimationPlayer

var state: State = State.MOVE
var move_speed: float = MOVE_SPEED
var normalized_input: Vector2 = Vector2.ZERO
var anim_dir: String = "down"
var dash_dir: Vector2 = Vector2.ZERO
var attack_instance: Node2D = null
var mana: float = MANA
var dash_timer: float = 0.0
var dash_cd_timer: float = 0.0
var input_vector: Vector2 = Vector2.ZERO

const attack_dash_scene: PackedScene = preload("res://scene/player/attack_dash_player.tscn")
const attack_parry_scene: PackedScene = preload("res://scene/player/attack_parry.tscn")
const attack_rolling_scene: PackedScene = preload("res://scene/player/attack_rolling.tscn")
const attack_slash_scene: PackedScene = preload("res://scene/player/attack_slash.tscn")

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
	var start_marker = get_parent().get_node("Markers").get_node_or_null("PlayerStartMarker") as Marker2D
	if start_marker:
		global_position = start_marker.global_position
	else:
		push_error("PlayerStartMarker is missing in the scene.")

func get_direction() -> float:
	return (get_global_mouse_position() - global_position).angle()

# アクション入力は Input ポーリングで処理する。
# プレイヤーは SubViewport 内にいて _input イベントが届かないことがあるため、
# 移動(Input.get_vector)と同じ方式に統一する。_physics_process から毎フレーム呼ぶ。
func _handle_actions() -> void:
	if state != State.MOVE:
		return

	# if Input.is_action_just_pressed("dash") and dash_cd_timer <= 0:
	# 	if not mana_component.spend(10.0):
	# 		return
	# 	dash_timer = dash_duration
	# 	dash_cd_timer = dash_cooldown
	# 	dash_dir = normalized_input if normalized_input != Vector2.ZERO else (get_global_mouse_position() - global_position).normalized()

	# 	attack_instance = attack_dash_scene.instantiate()
	# 	add_child(attack_instance)
	# 	attack_instance.global_position = global_position

	# 	state = State.DASH
	# 	return

	if Input.is_action_just_pressed("rolling"):
		if not mana_component.spend(5.0):
			return
		dash_timer = rolling_duration
		dash_dir = normalized_input if normalized_input != Vector2.ZERO else (get_global_mouse_position() - global_position).normalized()

		attack_instance = attack_rolling_scene.instantiate()
		add_child(attack_instance)
		attack_instance.global_position = global_position

		dash_started.emit()

		state = State.DASH

	if Input.is_action_just_pressed("parry"):
		if not mana_component.spend(10.0):
			return
		attack_instance = attack_parry_scene.instantiate()
		add_child(attack_instance)
		attack_instance.global_position = global_position
		if attack_instance.has_method("parried"):
			attack_instance.parried.connect(_on_attack_finished)
		attack_instance.attack_finished.connect(_on_attack_finished)
		attack_instance.rotation = global_position.angle_to_point(get_global_mouse_position())

	if Input.is_action_just_pressed("slash"):
		if not mana_component.spend(5.0):
			return
		attack_instance = attack_slash_scene.instantiate()
		add_child(attack_instance)
		attack_instance.global_position = global_position

func _on_attack_finished() -> void:
	if attack_instance:
		attack_instance = null
		state = State.MOVE

func blowed_off(direction: Vector2) -> void:
	dash_timer = rolling_duration * 6.0
	dash_dir = direction

	attack_instance = attack_rolling_scene.instantiate()
	add_child(attack_instance)
	attack_instance.global_position = global_position

	dash_started.emit()

	state = State.DASH

func timer_control(delta: float) -> void:
	if dash_cd_timer > 0:
		dash_cd_timer -= delta
	if dash_timer > 0:
		dash_timer -= delta

func _on_died() -> void:
	print("Player has died due to mana depletion.")

func stop_movement(_t: String) -> void:
	set_sprite(Vector2.ZERO)
	set_process_to(false)

func _on_dialogue_finished(_t: String) -> void:
	set_process_to(true)

func set_sprite(input_vector: Vector2) -> void:
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

func play_animation(anim_name: String) -> void:
	attack_visual_anim.play(anim_name)

func _ready() -> void:
	state = State.MOVE
	mana_component.depleted.connect(_on_died)
	Dialogue.started.connect(stop_movement)
	Dialogue.finished.connect(_on_dialogue_finished)

func _physics_process(delta: float) -> void:
	timer_control(delta)
	_handle_actions()

	if(state == State.DASH):
		velocity = dash_dir * dash_speed

		if (dash_timer <= 0):
			if attack_instance:
				attack_instance.queue_free()
			state = State.MOVE
	
	if (state == State.MOVE):
		input_vector = Input.get_vector("left", "right", "up", "down")
		velocity = input_vector * move_speed
		normalized_input = input_vector.normalized() if input_vector != Vector2.ZERO else Vector2.ZERO
		set_sprite(input_vector)

	# 足元が敵色なら鈍足
	if paint_layer:
		var color_at_feet = paint_layer.get_color_owner_at(global_position)
		if color_at_feet == paint_layer.KURENAI:
			move_speed = MOVE_SPEED * 0.5
			mana_component.spend(2.0 * delta)
		elif color_at_feet == paint_layer.AI:
			move_speed = MOVE_SPEED * 1.3
			mana_component.restore(20.0 * delta)
		else:
			move_speed = MOVE_SPEED
			mana_component.restore(10.0 * delta)

	move_and_slide()
