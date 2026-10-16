@tool
class_name HudAutoFader
extends Control
## area_offset / area_size で指定した矩形を判定範囲とし、見張っているキャラが入ったら fade_target を半透明にする。

const EDITOR_FILL := Color(1.0, 0.25, 0.25, 0.2)
const EDITOR_LINE := Color(1.0, 0.25, 0.25, 0.8)

@export var fade_target: CanvasItem:
	set(value):
		fade_target = value
		update_configuration_warnings()
@export var watched: Array[Node2D] = []

@export_group("判定範囲")
@export var area_offset: Vector2 = Vector2.ZERO:
	set(value):
		area_offset = value
		queue_redraw()
@export var area_size: Vector2 = Vector2(120.0, 40.0):
	set(value):
		area_size = value.max(Vector2.ZERO)
		queue_redraw()
@export var release_extra_margin: float = 6.0

@export_group("フェード")
@export var hidden_alpha: float = 0.25
@export var fade_time: float = 0.15

@export_group("デバッグ")
@export var debug_draw: bool = false

var _is_hidden := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func watch(nodes: Array) -> void:
	watched.assign(nodes)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or fade_target == null:
		return
	_is_hidden = _is_overlapped()
	var target := hidden_alpha if _is_hidden else 1.0
	var speed := (1.0 - hidden_alpha) / fade_time
	fade_target.modulate.a = move_toward(fade_target.modulate.a, target, speed * delta)
	if debug_draw:
		queue_redraw()


func _local_detection_rect() -> Rect2:
	var m := release_extra_margin if _is_hidden else 0.0
	return Rect2(area_offset, area_size).grow(m)


func _is_overlapped() -> bool:
	var area := get_global_transform_with_canvas() * _local_detection_rect()
	for node in watched:
		if is_instance_valid(node) and node.is_visible_in_tree() \
				and area.has_point(node.get_global_transform_with_canvas().origin):
			return true
	return false


func _draw() -> void:
	if Engine.is_editor_hint():
		var rect := Rect2(area_offset, area_size)
		draw_rect(rect, EDITOR_FILL)
		draw_rect(rect, EDITOR_LINE, false, 1.0)
		return
	if not debug_draw:
		return
	draw_rect(_local_detection_rect(), EDITOR_LINE, false, 1.0)
	var canvas_to_local := get_global_transform_with_canvas().affine_inverse()
	for node in watched:
		if is_instance_valid(node):
			draw_circle(canvas_to_local * node.get_global_transform_with_canvas().origin, 2.0, Color.YELLOW)


func _get_configuration_warnings() -> PackedStringArray:
	if fade_target == null:
		return ["fade_target に半透明にしたいノードを設定してください"]
	return []