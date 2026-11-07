class_name OutlineDisplayZone
extends Node2D

## 子孫のどれか 1 つ目の Area2D に入った瞬間
signal target_entered(body: Node2D)
## 子孫のすべての Area2D から出た瞬間
signal target_exited(body: Node2D)

@export var target_groups: Array[StringName] = [&"player", &"boss"]

## body ごとに「今いくつの Area2D と重なっているか」
var _overlap_counts: Dictionary[Node2D, int] = {}


func _ready() -> void:
	for area: Area2D in find_children("*", "Area2D", true, false):
		area.body_entered.connect(_on_area_body_entered)
		area.body_exited.connect(_on_area_body_exited)


func is_inside(body: Node2D) -> bool:
	return _overlap_counts.has(body)


func reset() -> void:
	_overlap_counts.clear()


func _is_target(body: Node2D) -> bool:
	for group in target_groups:
		if body.is_in_group(group):
			return true
	return false


func _on_area_body_entered(body: Node2D) -> void:
	if not _is_target(body):
		return
	var count: int = _overlap_counts.get(body, 0) + 1
	_overlap_counts[body] = count
	if count == 1:
		target_entered.emit(body)


func _on_area_body_exited(body: Node2D) -> void:
	if not _overlap_counts.has(body):
		return
	var count := _overlap_counts[body] - 1
	if count > 0:
		_overlap_counts[body] = count
		return
	_overlap_counts.erase(body)
	target_exited.emit(body)
