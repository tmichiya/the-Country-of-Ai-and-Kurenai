class_name TutorialStepRepaint
extends TutorialStep
## 課題: 藍に塗られた床が、標的の薙ぎで紅に塗り替えられるのを見届ける。

@export var required_attacks: int = 2
@export var prepaint_radius: float = 70.0

var _start_count: int = 0


func _begin() -> void:
	ctx.paint_layer.paint_blob(dummy.global_position, prepaint_radius, ctx.paint_layer.AI)
	_start_count = dummy.attack_count
	dummy.set_attack_enabled(true)


func _done() -> int:
	return dummy.attack_count - _start_count


func _is_cleared() -> bool:
	return _done() >= required_attacks and not dummy.is_attacking()


func _progress_text() -> String:
	return "近づいて薙ぎを見る  %d / %d" % [mini(_done(), required_attacks), required_attacks]


func _end() -> void:
	dummy.set_attack_enabled(false)
