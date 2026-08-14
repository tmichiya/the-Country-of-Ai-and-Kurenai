extends Node

var akane: CharacterBody2D
var player: CharacterBody2D
var paint_layer: Node2D
var last_attack: String = ""
var last_stance: String = ""
var current_stance: AttackStance

enum AttackStance {
	NEUTRAL,
	OFFENSIVE,
	RETREAT,
	PAINT
}

var attack_stances: Array = ["NEUTRAL", "OFFENSIVE", "RETREAT", "PAINT"]

func get_attack_scores() -> Dictionary:
	var scores := {}
	for name in akane.attacks:
		scores[name] = _evaluate_attack(name)
	return scores

func choose_attack() -> String:
	var scores := {}
	for name in akane.attacks:
		scores[name] = _evaluate_attack(name)
	var chosen_attack = _pick_weighted(scores, 3)
	last_attack = chosen_attack
	return chosen_attack

# Attack evaluation

func _evaluate_attack(attack_name: String) -> float:
	var dist := akane.global_position.distance_to(player.global_position)
	var mana : float = akane.mana_component.get_mana()
	var score := 0.0
	
	match attack_name:
		"karatake":
			score = _range_score(dist, 100, 400)
		"onagi":
			score = _range_score(dist, 0, 50, 1)
		"sandankuzushi":
			score = _range_score(dist, 50, 150) * 1.2 + _last_attack_score("sandankuzushi", 0.5)
		"jisome":
			score = _range_score(dist, 100, 150) * _paint_pressure() * 2.0
		"jinrai":
			score = _range_score(dist, 150, 400)
	
	# 共通の減点
	if attack_name == last_attack:
		score *= 0.3          # 連発を避ける
	if mana < akane.attack_mana_cost[attack_name]:
		score = 0.0           # 撃てない
	
	return score

func _range_score(dist: float, min_range: float, max_range: float, dir_inv: bool = false) -> float:
	var clamped_dist : float = clamp(dist, min_range, max_range)
	var t := inverse_lerp(min_range, max_range, clamped_dist)
	if dir_inv:
		t = 1.0 - t
	return max(t, 0.1)

func _paint_pressure() -> float:
	var paint_coverage : float = paint_layer.get_paint_coverage(paint_layer.KURENAI, 100.0, akane.global_position)
	return paint_coverage

func _pick_weighted(scores: Dictionary, pick_pool_size: int = 3) -> String:
	var pool := scores.duplicate()
	var top_score := []

	for i in range(pick_pool_size):
		if pool.is_empty():
			break
		var best_name
		var best_score := -INF
		for name in pool.keys():
			if pool[name] > best_score:
				best_score = pool[name]
				best_name = name
		if best_score <= 0.0:
			break
		top_score.append({"name": best_name, "score": best_score})
		pool.erase(best_name)
	
	print("Scores: %s" % scores)
	print("Top scores: " % top_score)
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

# attack stance evaluation

func _evaluate_stance(stance: String) -> float:
	var dist := akane.global_position.distance_to(player.global_position)
	var score := 0.0
	var sub_score := 0.0
	var remaped_sub_score := 0.0
	var player_mana_ratio = player.mana_component.get_mana() / player.mana_component.get_max_mana()
	var akane_mana_ratio = akane.mana_component.get_mana() / akane.mana_component.get_max_mana()

	match stance:
		"NEUTRAL":
			# 敵mana多, 自mana少, 自インク多 
			sub_score = _range_score(player_mana_ratio, 0.6, 1.0) + _range_score(akane_mana_ratio, 0.0, 0.6, 1) + _range_score(paint_layer.get_paint_coverage(paint_layer.KURENAI, 100.0, akane.global_position), 0.3, 1.0)
			remaped_sub_score = remap(sub_score, 0.0, 3.0, 0.0, 0.5)
			score = _range_score(dist, 60, 200) + remaped_sub_score
		"OFFENSIVE":
			# 自インク多, 敵mana少
			sub_score = _range_score(paint_layer.get_paint_coverage(paint_layer.KURENAI, 100.0, akane.global_position), 0.3, 1.0) + _range_score(player_mana_ratio, 0.0, 0.6, 1)
			remaped_sub_score = remap(sub_score, 0.0, 2.0, 0.0, 0.5)
			score = _range_score(akane_mana_ratio, 0.0, 1.0) + remaped_sub_score
		"RETREAT":
			# 敵mana多, 敵近, 自インク少, 敵インク多
			sub_score = _range_score(player_mana_ratio, 0.6, 1.0) + _range_score(dist, 0, 100, 1) + _range_score(paint_layer.get_paint_coverage(paint_layer.KURENAI, 100.0, akane.global_position), 0.5, 1.0, 1) + _range_score(paint_layer.get_paint_coverage(paint_layer.AI, 50.0, akane.global_position), 0.5, 1.0)
			remaped_sub_score = remap(sub_score, 0.0, 4.0, 0.0, 0.5)
			score = _range_score(akane_mana_ratio, 0.0, 0.6, 1) + remaped_sub_score
		"PAINT":
			# 自mana多, 敵遠, 敵インク多
			sub_score = _range_score(akane_mana_ratio, 0.6, 1.0) + _range_score(dist, 150, 400) + _range_score(paint_layer.get_paint_coverage(paint_layer.AI, 50.0, akane.global_position), 0.5, 1.0)
			remaped_sub_score = remap(sub_score, 0.0, 3.0, 0.0, 0.5)
			score = _range_score(paint_layer.get_paint_coverage(paint_layer.KURENAI, 80.0, akane.global_position), 0.0, 0.7, 1) + remaped_sub_score

	if stance == last_stance:
		score += 0.2
	return score

func get_attack_stance() -> AttackStance:
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

func set_current_stance() -> void:
	current_stance = get_attack_stance()

func _ready() -> void:
	akane = get_parent() as CharacterBody2D
	player = akane.player
	paint_layer = akane.paint_layer

func _process(delta: float) -> void:
	if not akane or not player:
		return
