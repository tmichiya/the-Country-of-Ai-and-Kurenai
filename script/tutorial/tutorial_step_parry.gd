class_name TutorialStepParry
extends TutorialStep
## 課題: 標的の薙ぎを決まった回数パリィする。

@export var required_parries: int = 3
@export_range(0.0, 1.0) var start_mana_ratio: float = 0.4

var _parries: int = 0


func _begin() -> void:
	_parries = 0
	ctx.set_player_mana_ratio(start_mana_ratio)
	dummy.attack_parried.connect(_on_attack_parried)
	dummy.set_attack_enabled(true)


func _on_attack_parried() -> void:
	_parries += 1


func _is_cleared() -> bool:
	return _parries >= required_parries and not dummy.is_attacking()


func _progress_text() -> String:
	return "薙ぎをパリィ  %d / %d" % [mini(_parries, required_parries), required_parries]


func _end() -> void:
	dummy.set_attack_enabled(false)
	dummy.attack_parried.disconnect(_on_attack_parried)
