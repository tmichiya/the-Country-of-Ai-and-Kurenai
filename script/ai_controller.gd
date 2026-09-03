extends Node

var hakubo: CharacterBody2D
var player: CharacterBody2D
var paint_layer: Node2D
var last_attack: String = ""
var last_stance: String = ""
var current_stance: AttackStance
var do_emergency_dash: bool = false

enum AttackStance {
	NEUTRAL,
	OFFENSIVE,
	RETREAT,
	PAINT
}

var attack_stances: Array = ["NEUTRAL", "OFFENSIVE", "RETREAT", "PAINT"]

# 攻撃の一覧・コスト・シーンは hakubo.gd の attack_roster を単一の真実の源とする。
# ここでは hakubo.get_attack_ids() / hakubo.get_attack_def(id) 経由で参照する。

func get_attack_scores() -> Dictionary:
	var scores := {}
	for attack_id in hakubo.get_attack_ids():
		scores[attack_id] = _evaluate_attack(attack_id)
	return scores

func choose_attack() -> String:
	var scores := {}
	for attack_id in hakubo.get_attack_ids():
		scores[attack_id] = _evaluate_attack(attack_id)
	var chosen := _pick_weighted(scores, 3)
	last_attack = chosen
	return chosen

# === attack evaluation ===

func _evaluate_attack(attack_id: String) -> float:
	var def: AttackData = hakubo.get_attack_def(attack_id)
	if def == null:
		return 0.0

	var dist := hakubo.global_position.distance_to(player.global_position)
	var mana : float = hakubo.mana_component.get_mana()
	var score := 0.0

	if def.is_dash:
		# dash は「現在スタンスの適正距離」に対する評価（データの min/max ではなく特殊式）
		var appropriate_dist := _appropriate_distance(current_stance)
		var distance_score := (_range_score(dist, appropriate_dist - 50, appropriate_dist) + _range_score(dist, appropriate_dist - 50, appropriate_dist, true)) * 0.5
		var sub := _last_attack_score("dash", 1.0) + _last_attack_score("jinrai", 1.0)

		var emergency_dash_attack_score = 0
		if do_emergency_dash:
			emergency_dash_attack_score = 2.0
			do_emergency_dash = false

		score = remap(distance_score, 0.0, 1.0, 0.0, 1.0) + remap(sub, 0.0, 2.0, 0.0, 0.5) + emergency_dash_attack_score
	else:
		# 基本の距離スコア（AttackData のパラメータで駆動）
		score = _range_score(dist, def.min_range, def.max_range, def.range_inverted) * def.base_multiplier
		# 攻撃固有のコンボ加点（アルゴリズムはコード側に残す）
		score += _combo_bonus(attack_id)
		score += _paint_bonus(attack_id)

	score *= _stance_modifier(attack_id)

	# 共通の減点
	if attack_id == last_attack:
		score *= 0.9  # 連発を避ける
	if mana < def.mana_cost:
		score = 0.0   # 撃てない

	return score

func _paint_bonus(attack_id: String) -> float:
	match attack_id:
		"onagi":
			return remap(1.0 - paint_layer.get_paint_coverage(paint_layer.KURENAI, 50.0, hakubo.global_position), 0.3, 1.0, 0.0, 0.5)
		"jisome":
			return remap(1.0 - paint_layer.get_paint_coverage(paint_layer.KURENAI, 150.0, hakubo.global_position), 0.3, 1.0, 0.0, 0.5)
	return 0.0

# 直前の攻撃に応じた「連携ボーナス」。技ごとの特殊ロジックだけをここに残す。
func _combo_bonus(attack_id: String) -> float:
	match attack_id:
		"sandankuzushi":
			var sub := _last_attack_score("jinrai", 1.0) + _last_attack_score("dash", 1.0)
			return remap(sub, 0.0, 2.0, 0.0, 0.5)
		"jisome":
			var sub := _last_attack_score("onagi", 1.0) * 0.9
			return remap(sub, 0.0, 1.0, 0.0, 0.5)
	return 0.0

func _stance_modifier(attack_id: String) -> float:
	var def: AttackData = hakubo.get_attack_def(attack_id)
	if def == null:
		return 1.0
	# 現在スタンス名（"OFFENSIVE" 等）で相性を引く。未指定・NEUTRAL は 1.0。
	var stance_name: String = attack_stances[current_stance]
	return def.stance_affinity.get(stance_name, 1.0)

func _appropriate_distance(stance: AttackStance) -> float:
	match stance:
		AttackStance.NEUTRAL:
			return 150.0
		AttackStance.OFFENSIVE:
			return 50.0
		AttackStance.RETREAT:
			return 150.0
		AttackStance.PAINT:
			return 100.0
	return 0

func _range_score(dist: float, min_range: float, max_range: float, dir_inv: bool = false) -> float:
	var clamped_dist : float = clamp(dist, min_range, max_range)
	var t := inverse_lerp(min_range, max_range, clamped_dist)
	if dir_inv:
		t = 1.0 - t
	return max(t, 0.1)

func _pick_weighted(scores: Dictionary, pick_pool_size: int = 3) -> String:
	var pool := scores.duplicate()
	var top_score := []

	for i in range(pick_pool_size):
		if pool.is_empty():
			break
		var best_name
		var best_score := -INF
		for attack_name in pool.keys():
			if pool[attack_name] > best_score:
				best_score = pool[attack_name]
				best_name = attack_name
		if best_score <= 0.0:
			break
		top_score.append({"name": best_name, "score": best_score})
		pool.erase(best_name)
	
	if top_score.is_empty():
		return ""

	var total := 0.0
	for e in top_score:
		total += e["score"]

	var r := randf() * total
	var cum := 0.0
	for e in top_score:
		cum += e["score"]
		if r <= cum:
			return e["name"]
	return top_score[-1]["name"]

func _last_attack_score(target: String, score_intensity: float) -> float:
	if last_attack != target:
		return 0.0
	return score_intensity

# === attack stance evaluation

func _evaluate_stance(stance: String) -> float:
	var dist := hakubo.global_position.distance_to(player.global_position)
	var score := 0.0
	var sub_score := 0.0
	var remaped_sub_score := 0.0
	var player_mana_ratio = player.mana_component.get_mana() / player.mana_component.get_max_mana()
	var hakubo_mana_ratio = hakubo.mana_component.get_mana() / hakubo.mana_component.get_max_mana()

	match stance:
		"NEUTRAL":
			# 敵mana多, 自mana少, 自インク多 
			sub_score = _range_score(player_mana_ratio, 0.6, 1.0) + _range_score(hakubo_mana_ratio, 0.0, 0.6, 1) + _range_score(paint_layer.get_paint_coverage(paint_layer.KURENAI, 100.0, hakubo.global_position), 0.3, 1.0)
			remaped_sub_score = remap(sub_score, 0.0, 3.0, 0.0, 0.5)
			score = _range_score(dist, 60, 200) + remaped_sub_score
		"OFFENSIVE":
			# 自インク多, 敵mana少
			sub_score = _range_score(paint_layer.get_paint_coverage(paint_layer.KURENAI, 100.0, hakubo.global_position), 0.3, 1.0) + _range_score(player_mana_ratio, 0.0, 0.6, 1)
			remaped_sub_score = remap(sub_score, 0.0, 2.0, 0.0, 0.5)
			score = _range_score(hakubo_mana_ratio, 0.0, 1.0) + remaped_sub_score
		"RETREAT":
			# 敵mana多, 敵近, 自インク少, 敵インク多
			sub_score = _range_score(player_mana_ratio, 0.6, 1.0) + _range_score(dist, 0, 100, 1) + _range_score(paint_layer.get_paint_coverage(paint_layer.KURENAI, 100.0, hakubo.global_position), 0.5, 1.0, 1) + _range_score(paint_layer.get_paint_coverage(paint_layer.AI, 50.0, hakubo.global_position), 0.5, 1.0)
			remaped_sub_score = remap(sub_score, 0.0, 4.0, 0.0, 0.5)

			# emergency dash が発生している場合は、RETREAT の評価を大幅に上げる
			if do_emergency_dash:
				remaped_sub_score += 2.0

			score = _range_score(hakubo_mana_ratio, 0.0, 0.6, 1) + remaped_sub_score
		"PAINT":
			# 自mana多, 敵遠, 敵インク多
			sub_score = _range_score(hakubo_mana_ratio, 0.6, 1.0) + _range_score(dist, 150, 400) + _range_score(paint_layer.get_paint_coverage(paint_layer.AI, 50.0, hakubo.global_position), 0.5, 1.0)
			remaped_sub_score = remap(sub_score, 0.0, 3.0, 0.0, 0.5)
			score = _range_score(paint_layer.get_paint_coverage(paint_layer.KURENAI, 80.0, hakubo.global_position), 0.0, 0.7, 1) + remaped_sub_score

	if stance == last_stance:
		score += 0.2
	return score

func _get_attack_stance() -> AttackStance:
	var stances := {}
	for stance in attack_stances:
		stances[stance] = _evaluate_stance(stance)
	var chosen_stance = _pick_weighted(stances, 1)
	last_stance = chosen_stance
	if chosen_stance == "NEUTRAL":
		return AttackStance.NEUTRAL
	elif chosen_stance == "OFFENSIVE":
		return  AttackStance.OFFENSIVE
	elif chosen_stance == "RETREAT":
		return AttackStance.RETREAT
	elif chosen_stance == "PAINT":
		return AttackStance.PAINT
	else:
		print("Unknown stance chosen: %s" % chosen_stance)
		return chosen_stance

func get_stance_scores() -> Dictionary:
	var scores := {}
	for stance in attack_stances:
		scores[stance] = _evaluate_stance(stance)
	return scores

func get_current_stance() -> AttackStance:
	return current_stance

func set_current_stance() -> void:
	current_stance = _get_attack_stance()

# === ordinary movement ===

@export var MOVEMENT_SPEED: float = 80.0
var movement_speed: float = MOVEMENT_SPEED
var is_changed_ordinary_movement: bool = false

func _desired_speed(delta: float) -> void:
	if not hakubo or not player:
		return

	movement_speed = MOVEMENT_SPEED

	var current_floor_color = paint_layer.get_color_owner_at(hakubo.global_position)
	if current_floor_color == paint_layer.AI:
		movement_speed = movement_speed * 0.5
	elif current_floor_color == paint_layer.KURENAI:
		movement_speed = movement_speed * 1.3

	is_changed_ordinary_movement = true

func _desired_velocity() -> Vector2:
	if current_stance == AttackStance.RETREAT or current_stance == AttackStance.PAINT or current_stance == AttackStance.NEUTRAL:
		return Vector2.from_angle(hakubo.ai_controller.calc_retreat_direction(false)) * movement_speed
	else:
		return Vector2.from_angle(hakubo.ai_controller.calc_retreat_direction(true)) * movement_speed


# === emergency dash system ===
var emergency_dash_score: float = 0.0
var EMERGENCY_DASH_THRESHOLD: float = 20.0
var MAX_SCORE_MODIFIER: float = 0.1

func _evaluate_emergency_dash_score(weight: float = 1.0) -> void:
	var direct_direction = (hakubo.global_position - player.global_position).normalized()
	var player_direction = hakubo.get_player_vector()
	var diff_angle = direct_direction.angle_to(player_direction) if player_direction.length() > 0 else (-PI)
	
	var distance_to_player = hakubo.get_player_distance()
	var processed_distance_score = remap(_range_score(distance_to_player, 0.0, 400.0, true), 0.0, 1.0, 0.8, 1.2)  # 近いほどスコアが高くなる
	
	if abs(diff_angle) < deg_to_rad(60):
		emergency_dash_score = clamp((emergency_dash_score + MAX_SCORE_MODIFIER * weight) * processed_distance_score, 0.0, EMERGENCY_DASH_THRESHOLD)
	else:
		var remaped_score = remap(abs(diff_angle), deg_to_rad(60), deg_to_rad(180), 0.0, MAX_SCORE_MODIFIER) * (-1)
		emergency_dash_score = clamp((emergency_dash_score + remaped_score) * processed_distance_score, 0.0, EMERGENCY_DASH_THRESHOLD)

func _determine_do_dash() -> void:
	if emergency_dash_score >= EMERGENCY_DASH_THRESHOLD:
		# すでにダッシュ中なら、scoreもリセットしてreturn
		if hakubo.chosen_attack == "dash":
			emergency_dash_score = 0.0
			print("Already dashing, emergency_dash_score reset to 0.0")
			return
		# 攻撃予備動作中は緊急ダッシュ可能
		# 別の攻撃中は緊急ダッシュ不可。ただし終了後はただちにダッシュ
		if hakubo.attack_instance and hakubo.is_telegraphing():
			# manaに余裕がある場合はそのまま実行
			if hakubo.mana_component.get_mana_percentage() > 0.7:
				print("Attack in progress, cannot emergency dash now. Will dash after attack.")
				return

		# jump中は緊急ダッシュ不可
		if hakubo.is_jumping:
			print("Jump in progress, cannot emergency dash now. Will dash after jump.")
			emergency_dash_score = 0.0
			return

		print("Emergency dash triggered!")

		hakubo.force_attack_to_finish()
		do_emergency_dash = true
		emergency_dash_score = 0.0   # 発動したら必ずリセット。毎フレーム連続発動して攻撃が多重生成されるのを防ぐ

# playerのdashによる接近はより警戒
func _player_dash_detected() -> void:
	_evaluate_emergency_dash_score(20.0)

# === movement direction system === 

# 以下の合計ベクトル
# 1. プレイヤーからの退避方向（hakubo.global_position - player.global_position）
# 2. 円形フィールドの接線方向ベクトル
# 3. hakuboから円形フィールドの中心への方向ベクトル（center_marker.global_position - hakubo.global_position）
func calc_retreat_direction(invert: bool) -> float:
	if not hakubo:
		return 0.0

	var inv_mult = -1.0 if invert else 1.0

	var direct_retreat_dir = (hakubo.global_position - hakubo.get_player_position()).normalized() * inv_mult
	var circle_tangent_dir = hakubo.battle_field_center_marker.global_position.direction_to(hakubo.global_position).orthogonal().normalized()
	circle_tangent_dir = _get_similar_direction_vector_from_opposite(circle_tangent_dir, direct_retreat_dir)
	var center_direction_dir = (hakubo.battle_field_center_marker.global_position - hakubo.global_position).normalized()

	var battle_field_radius = 268
	var distance_to_center = (hakubo.battle_field_center_marker.global_position - hakubo.global_position).length()
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

# === initialization and process ===

func _ready() -> void:
	hakubo = get_parent() as CharacterBody2D
	player = hakubo.player
	paint_layer = hakubo.paint_layer

	hakubo.player.dash_started.connect(_player_dash_detected)

func _process(delta: float) -> void:
	if not hakubo or not player:
		push_error("Hakubo or player is null in _process()")
		return

	# emergency dash system 
	_evaluate_emergency_dash_score()
	_determine_do_dash()

	if hakubo.state == hakubo.State.WALK:
		if not is_changed_ordinary_movement:
			_desired_speed(delta)
			hakubo.velocity = _desired_velocity()
	else:
		is_changed_ordinary_movement = false
