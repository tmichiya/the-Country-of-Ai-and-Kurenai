extends Control

var player: CharacterBody2D
var akane: CharacterBody2D
var akane_ai_controller: Node

@onready var debug_attack_label: Label = $DebugAttackLabel
@onready var debug_stance_label: Label = $DebugStanceLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player = get_node("../../EffectLayer/SubViewportContainer/SubViewport/Player") as CharacterBody2D
	akane = get_node("../../EffectLayer/SubViewportContainer/SubViewport/Akane") as CharacterBody2D
	akane_ai_controller = akane.get_node("AIController") as Node

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# if player and akane:
	# 	debug_attack_label.text = "a"
	# 	var scores = akane_ai_controller.get_attack_scores()
	# 	debug_attack_label.text = "top_score_attack: %s\n" % _max_key(scores)
	# 	for attack in akane.attacks:
	# 		debug_attack_label.text += "  %s: %f\n" % [attack, scores[attack]]

	# 	debug_stance_label.text = "current_stance: %s\n" % akane_ai_controller.attack_stances[akane_ai_controller.current_stance]
	# 	var stance_scores = akane_ai_controller.get_stance_scores()
	# 	akane_ai_controller.set_current_stance()
	# 	for stance in akane_ai_controller.attack_stances:
	# 		debug_stance_label.text += "  %s: %f\n" % [stance, stance_scores[stance]]
	# 	debug_stance_label.text += "distance_to_player: %f\n" % akane.get_player_distance()
	# test
	player.mana_component.restore(100.0 * delta)
	akane.mana_component.restore(50.0 * delta)
	
	
	pass


func _max_key(d: Dictionary) -> String:
	var best_key := ""
	var best_val := -INF
	for k in d:
		if d[k] > best_val:
			best_val = d[k]
			best_key = k
	return best_key
