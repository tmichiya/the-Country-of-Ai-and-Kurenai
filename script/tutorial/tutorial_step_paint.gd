class_name TutorialStepPaint
extends TutorialStep
## 課題: 斬って標的のまわりを藍に塗る。

@export_range(0.0, 1.0) var target_coverage: float = 0.35
@export var coverage_radius: float = 70.0


func _coverage() -> float:
	return ctx.paint_layer.get_paint_coverage(ctx.paint_layer.AI, coverage_radius, dummy.global_position)


func _is_cleared() -> bool:
	return _coverage() >= target_coverage


func _progress_text() -> String:
	return "まわりを藍に塗る  %d%% / %d%%" % [int(_coverage() * 100.0), int(target_coverage * 100.0)]
