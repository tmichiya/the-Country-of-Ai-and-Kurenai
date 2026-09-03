extends Node2D

signal attack_finished

enum DashStance {
	OFFENSIVE,
	RETREAT,
	PAINT
}

var paint_layer: Node2D = null
var dash_count: int = 0
var dash_stance: DashStance = DashStance.OFFENSIVE

var hakubo: CharacterBody2D = null
var ai_controller: Node = null

var mana_cost: float = 10.0

func spend_mana() -> bool:
	if hakubo and hakubo.has_node("ManaComponent"):
		var mana_component = hakubo.get_node("ManaComponent") as ManaComponent
		if mana_component:
			return mana_component.spend(mana_cost)
	return false

func set_dash_stance(stance: DashStance) -> void:
	dash_stance = stance

func _on_animation_finished() -> void:
	attack_finished.emit()
	queue_free()

func _ready() -> void:
	print("Attack Dash ready")

	hakubo = get_parent() as CharacterBody2D
	ai_controller = get_parent().get_node("AIController") as Node

	if hakubo == null:
		push_error("Attack Dash: parent hakubo not found")
		return

	var distance_to_player : float = hakubo.get_player_distance()

	# dash_stance は hakubo から渡される DashStance（このスクリプト自身の enum）。
	# ai_controller.AttackStance と比較すると番号がズレて誤爆するので、必ず DashStance で判定する。
	match dash_stance:
		DashStance.OFFENSIVE:
			hakubo.dash(0.5, max(distance_to_player * 4.0, 1200.0))
		DashStance.RETREAT:
			var retreat_direction = ai_controller.calc_retreat_direction(false)
			hakubo.dash(0.5, 900.0, retreat_direction)
		DashStance.PAINT:
			var retreat_direction = ai_controller.calc_retreat_direction(false)
			hakubo.dash(0.5, 900.0, retreat_direction)
		_:
			push_error("Unknown dash stance: %s" % dash_stance)

	# if ai_controller:
	# 	current_stance = ai_controller.get_current_stance()
	# if hakubo:
	# 	if current_stance == ai_controller.AttackStance.RETREAT:
	# 		hakubo.dash(0.5, 600 * -1.0)
	# 	elif current_stance == ai_controller.AttackStance.OFFENSIVE:
	# 		hakubo.dash(0.5, distance_to_player * 4.0)
	# 	elif current_stance == ai_controller.AttackStance.PAINT:
	# 		hakubo.dash(0.5, 300 * -1.0)
	# 	elif current_stance == ai_controller.AttackStance.NEUTRAL:
	# 		hakubo.dash(0.5, 250)
		
func _process(delta: float) -> void:
	if hakubo:
		if hakubo.movement_state == hakubo.MovementState.NONE:
			_on_animation_finished()
