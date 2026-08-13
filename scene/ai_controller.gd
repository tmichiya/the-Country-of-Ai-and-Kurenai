extends Node

var akane: CharacterBody2D
var player: CharacterBody2D
var paint_layer: Node2D
var last_attack: String = ""

func _ready() -> void:
	akane = get_parent() as CharacterBody2D
	player = akane.player
	paint_layer = akane.paint_layer

func choose_attack() -> String:
	var scores := {}
	for name in akane.attacks:
		scores[name] = _evaluate(name)
	var chosen_attack = _pick_weighted(scores)
	last_attack = chosen_attack
	return chosen_attack

func _evaluate(attack_name: String) -> float:
	var dist := akane.global_position.distance_to(player.global_position)
	var mana : float = akane.mana_component.get_mana()
	var score := 0.0
	
	print("Evaluating attack: %s, distance: %f, mana: %f" % [attack_name, dist, mana])

	match attack_name:
		"karatake":
			score = _range_score(dist, 150, 400)
		"onagi":
			score = _range_score(dist, 0, 50)
		"sandankuzushi":
			score = _range_score(dist, 50, 150) * 1.2
		"jizome":
			score = _paint_pressure() * 2.0
		"jinrai":
			score = _range_score(dist, 150, 400)
	
	# 共通の減点
	if attack_name == last_attack:
		score *= 0.3          # 連発を避ける
	if mana < akane.attack_mana_cost[attack_name]:
		score = 0.0           # 撃てない
	
	return score

func _range_score(dist: float, min_range: float, max_range: float) -> float:
	var center := (min_range + max_range) * 0.5
	var half := (max_range - min_range) * 0.5
	var t : float = abs(dist - center) / half
	return maxf(0.05, 1.0 - t)

func _paint_pressure() -> float:
	var paint_coverage : float = paint_layer.get_paint_coverage(paint_layer.KURENAI, 100.0, akane.global_position)
	return paint_coverage

func _pick_weighted(scores: Dictionary) -> String:
	var pool := scores.duplicate()
	var top_score := []

	for i in range(3):
		if pool.is_empty():
			break
		var best_name := ""
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
