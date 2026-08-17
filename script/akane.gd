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

@export var MOVE_SPEED: float = 1.0
@export var MANA: float = 100.0

var state: State = State.IDLE
var state_timer: float = 1.0
var move_speed: float = MOVE_SPEED
var movement_dash_timer: float = 0.0
var movement_state: MovementState = MovementState.NONE
var movement_state_dash_strength: float = 0
var attack_instance: Node2D = null
var mana: float = MANA

@export var player: CharacterBody2D
@export var paint_layer: Node2D
const attack_karatake_scene: PackedScene = preload("res://scene/akane/attack_karatake.tscn")
const attack_onagi_scene: PackedScene = preload("res://scene/akane/attack_onagi.tscn")
const attack_sandankuzushi_scene: PackedScene = preload("res://scene/akane/attack_sandankuzushi.tscn")
const attack_jisome_scene: PackedScene = preload("res://scene/akane/attack_jisome.tscn")
const attack_jinrai_scene: PackedScene = preload("res://scene/akane/attack_jinrai.tscn")
const attack_dash_scene: PackedScene = preload("res://scene/akane/attack_dash_akane.tscn")

@onready var mana_component: ManaComponent = $ManaComponent
@onready var ai_controller: Node = $AIController

var attacks: Array = ["karatake", "onagi", "sandankuzushi", "jisome", "jinrai", "dash"]
var attack_mana_cost: Dictionary = {
	"karatake": 30.0,
	"onagi": 20.0,
	"sandankuzushi": 10.0,
	"jisome": 10.0,
	"jinrai": 20.0,
	"dash": 15.0
}
var attack_scenes: Dictionary = {
	"karatake": attack_karatake_scene,
	"onagi": attack_onagi_scene,
	"sandankuzushi": attack_sandankuzushi_scene,
	"jisome": attack_jisome_scene,
	"jinrai": attack_jinrai_scene,
	"dash": attack_dash_scene
}

func reset() -> void:
	state = State.IDLE
	state_timer = 1.0
	move_speed = MOVE_SPEED
	movement_dash_timer = 0.0
	movement_state = MovementState.NONE
	movement_state_dash_strength = 0
	if attack_instance:
		attack_instance.queue_free()
		attack_instance = null
	mana_component.restore(mana_component.get_max_mana())

func attack(attack_name: String) -> void:
	if not mana_component.spend(attack_mana_cost[attack_name]):
		_on_attack_finished()
		return

	attack_instance = attack_scenes[attack_name].instantiate()

	add_child(attack_instance)
	attack_instance.global_position = global_position
	attack_instance.paint_layer = paint_layer
	attack_instance.attack_finished.connect(_on_attack_finished)

	if attack_instance.has_signal("parried"):
		attack_instance.parried.connect(parried)

	state = State.ATTACK

func _on_attack_finished() -> void:
	attack_instance = null
	state = State.IDLE
	state_timer = randf_range(0, 1.0)

func is_telegraphing() -> bool:
	if attack_instance and attack_instance.has_method("is_playing_telegraph_animation"):
		return attack_instance.is_playing_telegraph_animation()
	return false

func dash(length: float, strength: float) -> void:
	movement_state = MovementState.DASH
	movement_dash_timer = length
	movement_state_dash_strength = strength

func rotate_towards_player() -> void:
	if player:
		var direction = Vector2(player.position.x - position.x, player.position.y - position.y).normalized()
		rotation = direction.angle()

func parried(uv: Vector2) -> void:
	if attack_instance and attack_instance.has_method("switch_is_telegraphing_to") and attack_instance.is_playing_telegraph_animation():
		attack_instance.switch_is_telegraphing_to(false)


	dash(0.5, -200.0)
	Effects.slowmotion(0, 0.12)
	Effects.shake(3.5)

	print("position: %s" % position)
	Effects.flash_impact(Effects.FLASH_WHITE, 1.0, 0.3, uv)

func get_player_distance() -> float:
	if player:
		return global_position.distance_to(player.global_position)
	return 0.0

func _on_died() -> void:
	print("Akane has died due to mana depletion.")

func _ready() -> void:
	_on_attack_finished()
	mana_component.depleted.connect(_on_died)

func _physics_process(delta: float) -> void:
	if state == State.IDLE:
		if player:
			var direction = Vector2(player.position.x - position.x, player.position.y - position.y).normalized()
			rotation = direction.angle()
		
		if state_timer > 0.0:
			state_timer -= delta
		else:
			# # テスト用
			# var chosen_attack = attacks[5]
			# print("AI chose attack: %s" % chosen_attack)

			var chosen_attack = ai_controller.choose_attack()
			print("AI chose attack: %s" % chosen_attack)
			if chosen_attack == "":
				print("No valid attack chosen. Remaining idle.")
				chosen_attack = attacks[randi() % len(attacks)]  # Default to "dash" if no valid attack is chosen

			attack(chosen_attack)
			state_timer = randf_range(1.0, 3.0)

	# 足元が敵色なら鈍足
	var color_at_feet = paint_layer.get_owner_at(global_position)
	if color_at_feet == paint_layer.AI:
		move_speed = MOVE_SPEED * 0.5
		mana_component.spend(2.0 * delta)
	elif color_at_feet == paint_layer.KURENAI:
		move_speed = MOVE_SPEED * 1.2
		mana_component.restore(6.0 * delta)
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
