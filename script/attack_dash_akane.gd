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

var akane: CharacterBody2D = null
var ai_controller: Node = null

func set_dash_stance(stance: DashStance) -> void:
	dash_stance = stance

func _on_animation_finished() -> void:
	attack_finished.emit()
	queue_free()

# 以下の合計ベクトル
# 1. プレイヤーからの退避方向（akane.global_position - player.global_position）
# 2. 円形フィールドの接線方向ベクトル
# 3. akaneから円形フィールドの中心への方向ベクトル（center_marker.global_position - akane.global_position）
func _calc_retreat_direction() -> float:
	if not akane or not ai_controller:
		return 0.0

	var direct_retreat_dir = (akane.global_position - akane.get_player_position()).normalized()
	var circle_tangent_dir = akane.battle_field_center_marker.global_position.direction_to(akane.global_position).orthogonal().normalized()
	circle_tangent_dir = _get_similar_direction_vector_from_opposite(circle_tangent_dir, direct_retreat_dir)
	var center_direction_dir = (akane.battle_field_center_marker.global_position - akane.global_position).normalized()

	var battle_field_radius = 268
	var distance_to_center = (akane.battle_field_center_marker.global_position - akane.global_position).length()
	var center_bias_strength = clampf((battle_field_radius - distance_to_center) / battle_field_radius, 0.0, 1.0)

	var processed_direct_retreat_dir = direct_retreat_dir * remap(clampf(center_bias_strength, 0.0, 0.5), 0.0, 0.5, 0.0, 1.0)
	var processed_circle_tangent_dir = circle_tangent_dir * remap(clampf(1.0 - center_bias_strength, 0.0, 0.5), 0.0, 0.5, 0.0, 1.0)
	var processed_center_direction_dir = center_direction_dir * remap(clampf(1.0 - center_bias_strength, 0.5, 1.0), 0.5, 1.0, 0.0, 1.0)

	# for debug BLUE
	var debug_direct_retreat_direction_stick = get_parent().get_node("DebugDirectRetreatDirectionStick") as Node2D
	if debug_direct_retreat_direction_stick:
		debug_direct_retreat_direction_stick.global_rotation = processed_direct_retreat_dir.angle()
		debug_direct_retreat_direction_stick.scale.x = processed_direct_retreat_dir.length()
	# for debug RED
	var debug_circle_tangent_direction_stick = get_parent().get_node("DebugCircleTangentDirectionStick") as Node2D
	if debug_circle_tangent_direction_stick:
		debug_circle_tangent_direction_stick.global_rotation = processed_circle_tangent_dir.angle()
		debug_circle_tangent_direction_stick.scale.x = processed_circle_tangent_dir.length()
	# for debug YELLOW
	var debug_center_direction_stick = get_parent().get_node("DebugCenterDirectionStick") as Node2D
	if debug_center_direction_stick:
		debug_center_direction_stick.global_rotation = processed_center_direction_dir.angle()
		debug_center_direction_stick.scale.x = processed_center_direction_dir.length()

	var retreat_direction = (processed_direct_retreat_dir + processed_circle_tangent_dir + processed_center_direction_dir).normalized()

	# for debug GREEN STICK
	var debug_direction_stick = get_parent().get_node("DebugDirectionStick") as Node2D
	if debug_direction_stick:
		debug_direction_stick.global_rotation = retreat_direction.angle()
		debug_direction_stick.scale.x = retreat_direction.length()

	return retreat_direction.angle()

# 接線ベクトルと接線ベクトル * (-1)のどちらかが、direct_retreat_dirに近いかを判定して、近い方を返す
func _get_similar_direction_vector_from_opposite(target_dir: Vector2, similar_base_dir: Vector2) -> Vector2:
	var opposite_dir = -target_dir.normalized()

	var dot_product = similar_base_dir.normalized().dot(opposite_dir)
	if dot_product > 0:
		return opposite_dir
	return target_dir.normalized()

func _ready() -> void:
	print("Attack Dash ready")

	akane = get_parent() as CharacterBody2D
	ai_controller = get_parent().get_node("AIController") as Node

	if akane == null:
		push_error("Attack Dash: parent Akane not found")
		return

	var distance_to_player : float = akane.get_player_distance()
	print("Akane found, distance to player: %f" % distance_to_player)

	# dash_stance は akane から渡される DashStance（このスクリプト自身の enum）。
	# ai_controller.AttackStance と比較すると番号がズレて誤爆するので、必ず DashStance で判定する。
	match dash_stance:
		DashStance.OFFENSIVE:
			akane.dash(0.5, max(distance_to_player * 4.0, 800.0))
		DashStance.RETREAT:
			var retreat_direction = _calc_retreat_direction()

			akane.dash(0.5, 900.0, retreat_direction)
		DashStance.PAINT:
			var retreat_direction = _calc_retreat_direction()
			akane.dash(0.5, -900.0, retreat_direction)
		_:
			push_error("Unknown dash stance: %s" % dash_stance)

	# if ai_controller:
	# 	current_stance = ai_controller.get_current_stance()
	# if akane:
	# 	if current_stance == ai_controller.AttackStance.RETREAT:
	# 		akane.dash(0.5, 600 * -1.0)
	# 	elif current_stance == ai_controller.AttackStance.OFFENSIVE:
	# 		akane.dash(0.5, distance_to_player * 4.0)
	# 	elif current_stance == ai_controller.AttackStance.PAINT:
	# 		akane.dash(0.5, 300 * -1.0)
	# 	elif current_stance == ai_controller.AttackStance.NEUTRAL:
	# 		akane.dash(0.5, 250)
		
func _process(delta: float) -> void:
	if akane:
		if akane.movement_state == akane.MovementState.NONE:
			_on_animation_finished()
