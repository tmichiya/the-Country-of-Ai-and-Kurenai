extends Control

@export var player: CharacterBody2D
@export var hakubo: CharacterBody2D
var hakubo_ai_controller: Node

@export var debug_attack_label: Label
@export var debug_stance_label: Label

@export var emergency_dash_score_bar: ColorRect

@export var boss_stage: Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hakubo_ai_controller = hakubo.get_node("AIController") as Node

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# if player and hakubo:
	# 	debug_attack_label.text = "a"
	# 	var scores = hakubo_ai_controller.get_attack_scores()
	# 	debug_attack_label.text = "top_score_attack: %s\n" % _max_key(scores)
	# 	for attack in hakubo.attacks:
	# 		debug_attack_label.text += "  %s: %f\n" % [attack, scores[attack]]

	# 	debug_stance_label.text = "current_stance: %s\n" % hakubo_ai_controller.attack_stances[hakubo_ai_controller.current_stance]
	# 	var stance_scores = hakubo_ai_controller.get_stance_scores()
	# 	hakubo_ai_controller.set_current_stance()
	# 	for stance in hakubo_ai_controller.attack_stances:
	# 		debug_stance_label.text += "  %s: %f\n" % [stance, stance_scores[stance]]
	# 	debug_stance_label.text += "distance_to_player: %f\n" % hakubo.get_player_distance()
	
	
	# test
	# player.mana_component.restore(100.0 * delta)
	# hakubo.mana_component.restore(10.0 * delta)
	# if hakubo.mana_component.get_mana() < 20.0:
	# 	hakubo.mana_component.restore(20.0 * delta)
	

	# emergency_dash
	emergency_dash_score_bar.scale.x = hakubo_ai_controller.emergency_dash_score / hakubo_ai_controller.EMERGENCY_DASH_THRESHOLD

	pass


func _max_key(d: Dictionary) -> String:
	var best_key := ""
	var best_val := -INF
	for k in d:
		if d[k] > best_val:
			best_val = d[k]
			best_key = k
	return best_key

func display_attack_scores() -> void:
	if player and hakubo:
		debug_attack_label.text = "state num : %s" % hakubo.state
		var scores = hakubo_ai_controller.get_attack_scores()
		debug_attack_label.text += "top_score_attack: %s\n" % _max_key(scores)
		while not scores.is_empty():
			var max_key = _max_key(scores)
			debug_attack_label.text += "%s: %f\n" % [max_key, scores[max_key]]
			scores.erase(max_key)

		debug_stance_label.text = "current_stance: %s\n" % hakubo_ai_controller.attack_stances[hakubo_ai_controller.current_stance]
		var stance_scores = hakubo_ai_controller.get_stance_scores()
		hakubo_ai_controller.set_current_stance()
		while not stance_scores.is_empty():
			var max_key = _max_key(stance_scores)
			debug_stance_label.text += " %s: %f\n" % [max_key, stance_scores[max_key]]
			stance_scores.erase(max_key)
		debug_stance_label.text += "distance_to_player: %f\n" % hakubo.get_player_distance()

	return
