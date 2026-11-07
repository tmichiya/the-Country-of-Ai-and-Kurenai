class_name TutorialStepRegenerate
extends TutorialStep
## 課題: 魔力を減らした状態から、藍の床の上で満タンまで戻す。

@export_range(0.0, 1.0) var start_mana_ratio: float = 0.4


func _begin() -> void:
	ctx.set_player_mana_ratio(start_mana_ratio)


func _ratio() -> float:
	return ctx.player.mana_component.get_mana_percentage()


func _is_cleared() -> bool:
	return _ratio() >= 0.995


func _progress_text() -> String:
	return "藍の上で魔力を満たす  %d%%" % int(_ratio() * 100.0)
