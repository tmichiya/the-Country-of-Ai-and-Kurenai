extends Node2D

signal attack_finished

var paint_layer: Node2D = null
var dash_count: int = 0
var current_stance

var akane: CharacterBody2D = null
var ai_controller: Node = null

func _on_animation_finished() -> void:
	attack_finished.emit()
	queue_free()

func _ready() -> void:
	print("Attack Dash ready")

	akane = get_parent() as CharacterBody2D
	ai_controller = get_parent().get_node("AIController") as Node

	var distance_to_player = akane.get_player_distance()

	if ai_controller:
		current_stance = ai_controller.get_current_stance()
	if akane:
		if current_stance == ai_controller.AttackStance.RETREAT:
			akane.dash(0.5, 600 * -1.0)
		elif current_stance == ai_controller.AttackStance.OFFENSIVE:
			akane.dash(0.5, distance_to_player * 4.0)
		elif current_stance == ai_controller.AttackStance.PAINT:
			akane.dash(0.5, 300 * -1.0)
		elif current_stance == ai_controller.AttackStance.NEUTRAL:
			akane.dash(0.5, 250)
		
func _process(delta: float) -> void:
	if ai_controller:
		current_stance = ai_controller.get_current_stance()
	if akane:
		if akane.movement_state == akane.MovementState.NONE:
			_on_animation_finished()
