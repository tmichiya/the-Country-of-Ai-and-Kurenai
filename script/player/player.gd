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
@export var mana_shortage_text: Node2D

@onready var mana_component: ManaComponent = $ManaComponent
@onready var animated_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var visual: Node2D = $Visual
@onready var hurtbox: Area2D = $Hurtbox

@onready var body_anim: AnimationPlayer = $BodyAnimationPlayer
@onready var attack_visual: Node2D = $AttackVisual

@onready var damage_particles: Node2D = $AttackVisual/DamageParticles
@onready var parry_attack_particles: Node2D = $AttackVisual/ParryAttackParticles

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

var easy_mana_cost_multiplier: float = 1.0

var interactible_object: Node2D = null

## 死亡演出中フラグ。
var is_dead: bool = false

## 操作をロックしている理由の集合。
var _control_locks: Dictionary = {}

const attack_dash_scene: PackedScene = preload("res://scene/player/attack_dash_player.tscn")
const attack_parry_scene: PackedScene = preload("res://scene/player/attack_parry.tscn")
const attack_rolling_scene: PackedScene = preload("res://scene/player/attack_rolling.tscn")
const attack_slash_scene: PackedScene = preload("res://scene/player/attack_slash.tscn")

func reset() -> void:
	state = State.MOVE
	move_speed = MOVE_SPEED
	dash_timer = 0.0
	dash_cd_timer = 0.0
	is_dead = false
	_control_locks.clear()
	_apply_control_locks()
	body_anim.play("reset")
	freeze_sprite_to_idle()
	mana_component.reset()
	if attack_instance:
		attack_instance.queue_free()
		attack_instance = null
	_set_position()

	if GameManager.easy_mode:
		easy_mana_cost_multiplier = 0.7
	else:
		easy_mana_cost_multiplier = 1.0

# === 操作ロック ===

## 理由つきで操作を止める。同じ理由で二重に掛けても副作用はない。
func add_control_lock(reason: String) -> void:
	_control_locks[reason] = true
	_apply_control_locks()

## 掛けた理由を取り下げる。他に誰も掛けていなければ動けるようになる。
func remove_control_lock(reason: String) -> void:
	_control_locks.erase(reason)
	_apply_control_locks()

func is_control_locked() -> bool:
	return not _control_locks.is_empty()

func _apply_control_locks() -> void:
	var active := _control_locks.is_empty()
	set_process_input(active)
	set_physics_process(active)
	if not active:
		velocity = Vector2.ZERO

func set_process_to(active: bool) -> void:
	if active:
		remove_control_lock("stage")
	else:
		add_control_lock("stage")

func set_hurtbox_monitor(active: bool) -> void:
	hurtbox.set_deferred("monitorable", active)

func set_interactable(active: bool, target: Node2D) -> void:
	if active:
		interactible_object = target
	else:
		interactible_object = null

func _set_position() -> void:
	var start_marker = get_parent().get_node("Markers").get_node_or_null("PlayerStartMarker") as Marker2D
	if start_marker:
		global_position = start_marker.global_position
	else:
		push_error("PlayerStartMarker is missing in the scene.")

func get_direction() -> float:
	return InputDevice.get_aim_angle(self)

func _handle_actions() -> void:
	if is_dead or state != State.MOVE:
		return

	if Input.is_action_just_pressed("rolling"):
		# 同じキーを使用するため、インタラクトを優先
		if interactible_object:
			interactible_object.interact()
			return

		if not mana_component.spend(10.0 * easy_mana_cost_multiplier):
			AudioManager.play_se("shortage_of_mana")
			mana_shortage_text.display_text(global_position)
			return
		dash_timer = rolling_duration
		dash_dir = normalized_input if normalized_input != Vector2.ZERO else (get_global_mouse_position() - global_position).normalized()

		attack_instance = attack_rolling_scene.instantiate()
		add_child(attack_instance)
		attack_instance.global_position = global_position

		dash_started.emit()

		state = State.DASH

		# rolling animation判定
		var input_vector_angle = input_vector.angle()
		if input_vector_angle >= -PI/4 - PI / 8 and input_vector_angle <= PI/4 + PI / 8:
			body_anim.play("rolling_right")
		elif absf(input_vector_angle) >= (3.0/4.0 * PI - PI / 8) and absf(input_vector_angle) <= PI:
			body_anim.play("rolling_left")

	if Input.is_action_just_pressed("parry"):
		if not mana_component.spend(10.0 * easy_mana_cost_multiplier):
			AudioManager.play_se("shortage_of_mana")
			mana_shortage_text.display_text(global_position)
			return
		attack_instance = attack_parry_scene.instantiate()
		add_child(attack_instance)
		attack_instance.global_position = global_position
		if attack_instance.has_method("parried"):
			attack_instance.parried.connect(_on_attack_finished)
		attack_instance.attack_finished.connect(_on_attack_finished)
		attack_instance.parried.connect(_on_parried)
		attack_instance.rotation = get_direction()

		# play particles
		parry_attack_particles.play_particle(InputDevice.get_aim_direction(self))

	if Input.is_action_just_pressed("slash"):
		if not mana_component.spend(8.0 * easy_mana_cost_multiplier):
			AudioManager.play_se("shortage_of_mana")
			mana_shortage_text.display_text(global_position)
			return
		if attack_instance:
			return
		attack_instance = attack_slash_scene.instantiate()
		add_child(attack_instance)
		attack_instance.global_position = global_position

func _on_attack_finished() -> void:
	if attack_instance:
		attack_instance = null
		state = State.MOVE

func _on_parried() -> void:
	print("Parry successful!")
	body_anim.play("parry_particles")

	Camera.camera_zoom_offset = Vector2(1.5, 1.5)
	await Camera.set_zoom_value(Camera.camera_zoom_offset + Vector2(0.5, 0.5), 0.2)
	await Camera.set_zoom_value(Camera.camera_zoom_offset - Vector2(0.5, 0.5), 0.2)


func blowed_off(direction: Vector2, duration_mul: float = 6.0) -> void:
	dash_timer = rolling_duration * duration_mul
	dash_dir = direction

	attack_instance = attack_rolling_scene.instantiate()
	add_child(attack_instance)
	attack_instance.global_position = global_position

	dash_started.emit()

	state = State.DASH

	damage_particles.rotation = direction.angle()
	damage_particles.play_particle()

func timer_control(delta: float) -> void:
	if dash_cd_timer > 0:
		dash_cd_timer -= delta
	if dash_timer > 0:
		dash_timer -= delta

func _on_died() -> void:
	print("Player has died due to mana depletion.")

# === アニメーション ===

## 被弾モーション。攻撃側から body_anim を直接叩かせず、必ずここを通す。
func play_damage_animation() -> void:
	if is_dead:
		return
	body_anim.play("damage")

## その場の向き（anim_dir）の idle スプライトで静止させる。
func freeze_sprite_to_idle() -> void:
	animated_sprite.play(anim_dir + "_idle")
	animated_sprite.stop()

## やられモーション。dir_x は「吹き飛ばされる向き」の x 成分。
func play_death_animation(dir_x: float) -> void:
	is_dead = true
	# 歩きアニメがループし続けないよう、まず idle で静止させる。
	# is_dead を立てると set_sprite() は何もしなくなるので、ここで明示的に行う。
	freeze_sprite_to_idle()
	if dir_x < 0.0:
		body_anim.play("reset")
		body_anim.play("dead_left")
	else:
		body_anim.play("reset")
		body_anim.play("dead_right")

func stop_movement(_t: String) -> void:
	set_sprite(Vector2.ZERO)
	add_control_lock("dialogue")

func _on_dialogue_finished(_t: String) -> void:
	# 会話が終わっても外すのは「会話ロック」だけ。
	# ステージ側が別の理由で止めているなら、そちらは効いたままになる。
	remove_control_lock("dialogue")

func _on_player_damaged() -> void:
	AudioManager.play_se("player_damage")

	_force_to_stop_playing_animation()

	Effects.shake(5.0)
	Effects.set_fade_color(Vector3(1.0, 0.24, 0.33))
	Effects.set_fade_alpha(0.5)
	await Effects.fade_out(0.2, 0.0)
	Effects.set_fade_alpha(1.0)
	Effects.set_fade_color(Vector3(0.0, 0.0, 0.0))

func _force_to_stop_playing_animation() -> void:
	# ほかのanimationが再生中にやると、その時の再生の状態で止まってしまうため、stop()する
	if body_anim.is_playing():
		body_anim.stop()
	body_anim.play("reset")

func set_sprite(input_vector: Vector2) -> void:
	# 死亡演出中にスプライトを差し替えると、倒れた絵が立ち絵に戻ってしまう
	if is_dead:
		return
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
	body_anim.play(anim_name)

func _ready() -> void:
	state = State.MOVE
	mana_component.depleted.connect(_on_died)
	Dialogue.started.connect(stop_movement)
	Dialogue.finished.connect(_on_dialogue_finished)
	Dialogue.cancelled.connect(_on_dialogue_finished)
	mana_component.damaged.connect(_on_player_damaged)

var footstep_timer: float = 0.0
var footstep_interval: float = 0.5
func _physics_process(delta: float) -> void:
	# debug
	# mana_component.restore(1000.0)

	timer_control(delta)
	_handle_actions()

	# footstep se
	footstep_timer += delta
	if state == State.MOVE:
		footstep_interval = 0.5
	elif state == State.DASH:
		footstep_interval = 0.1

	if footstep_timer >= footstep_interval and normalized_input != Vector2.ZERO:
		footstep_timer = 0.0
		AudioManager.play_se("player_footstep")

	# dash movement
	if(state == State.DASH):
		velocity = dash_dir * dash_speed

		if (dash_timer <= 0):
			if attack_instance:
				attack_instance.queue_free()
			state = State.MOVE
	
	if (state == State.MOVE and not is_dead):
		input_vector = InputDevice.get_move_direction()
		velocity = input_vector * move_speed
		normalized_input = input_vector.normalized() if input_vector != Vector2.ZERO else Vector2.ZERO
		set_sprite(input_vector)

	# 足元が敵色なら鈍足
	if paint_layer:
		var color_at_feet = paint_layer.get_color_owner_at(global_position)
		if color_at_feet == paint_layer.KURENAI:
			move_speed = MOVE_SPEED * 0.5
			mana_component.restore(10.0 * delta)
		elif color_at_feet == paint_layer.AI:
			move_speed = MOVE_SPEED * 1.4
			mana_component.restore(20.0 * delta)
		else:
			move_speed = MOVE_SPEED
			mana_component.restore(20.0 * delta)

	move_and_slide()
