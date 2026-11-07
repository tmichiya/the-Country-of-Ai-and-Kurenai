class_name Guide
extends Node2D
## 次の目的地を示すガイド。
##
## destinations を順にたどり、到達判定（ReachArea）に入るたびに次の目的地へ移動する。
## 目的地が画面内にあればワールドの三角（Marker）がそのまま見え、
## 画面外にあれば UILayer に置いた矢印（screen_arrow）を、目的地の方向の画面端に出す。
## プレイヤーが操作ロック中（会話・演出）のあいだはどちらも隠す。

## 目的地が変わったとき。全部たどり終えたら index は -1。
signal destination_changed(index: int)
## 最後の目的地に着いたとき。
signal finished

@export var destinations: Array[GuidePoint] = []
## 最初に向かう目的地の番号。restart() はここから始める。
@export var destination_number: int = 0
## 画面外のときに出す矢印。SubViewport の外（UILayer の直下）に置いた Sprite2D。
@export var screen_arrow: Node2D
## 操作ロック中は隠すために見る。
@export var player: Node
## 画面外の矢印を画面端からどれだけ内側に出すか。
@export var edge_margin: float = 14.0
## 画面外の矢印の脈動。
@export var arrow_pulse_speed: float = 5.0
@export var arrow_pulse_scale: float = 0.15

@onready var _marker: Node2D = $Marker
@onready var _reach_area: Area2D = $ReachArea
@onready var _reach_collision: CollisionShape2D = $ReachArea/CollisionShape2D

var _index: int = -1
var _default_shape: Shape2D
var _pulse_time: float = 0.0


func _ready() -> void:
	_default_shape = _reach_collision.shape
	_reach_area.entered.connect(_on_reached)
	if screen_arrow:
		screen_arrow.visible = false
	restart()


## destination_number から案内し直す。
func restart() -> void:
	start(destination_number)


## index 番目の目的地から案内する。範囲外なら案内をやめる。
func start(index: int) -> void:
	_go_to(index)


## 次の目的地へ進める。到達判定を待たずにスクリプトから進めたいとき用。
func advance() -> void:
	if is_guiding():
		_go_to(_index + 1)


## 案内をやめて、三角も矢印も消す。
func stop() -> void:
	_go_to(-1)


func is_guiding() -> bool:
	return _index >= 0 and _index < destinations.size()


func get_destination_index() -> int:
	return _index


func _go_to(index: int) -> void:
	var was_guiding := is_guiding()
	if index < 0 or index >= destinations.size():
		_index = -1
		_reach_area.set_monitoring_active(false)
		_set_shown(false)
		destination_changed.emit(_index)
		if was_guiding and index >= destinations.size():
			finished.emit()
		return

	_index = index
	var point := destinations[index]
	global_position = point.global_position
	_marker.position = point.marker_offset
	_reach_collision.shape = point.reach_shape if point.reach_shape else _default_shape
	# 動かした直後の幽霊 body_entered を避け、プレイヤーが重なっていれば一度離れるまで待つ
	_reach_area.set_monitoring_active(true)
	destination_changed.emit(_index)


## 物理の判定中（body_entered の中）は Area の形を変えられないので、次の目的地への移動は遅らせる。
func _on_reached() -> void:
	advance.call_deferred()


func _process(delta: float) -> void:
	if not is_guiding():
		return
	if _is_player_locked():
		_set_shown(false)
		return

	visible = true
	if screen_arrow == null:
		return

	var view_size := get_viewport().get_visible_rect().size
	var on_view := get_viewport().get_canvas_transform() * (global_position + _marker.position)
	var inner := Rect2(Vector2.ZERO, view_size).grow(-edge_margin)
	if inner.has_point(on_view):
		screen_arrow.visible = false
		return

	_pulse_time = fmod(_pulse_time + delta, TAU / arrow_pulse_speed)
	_place_arrow(on_view, view_size)


## 画面中央から目的地へ向かう線と、画面端（edge_margin 内側）の交点に矢印を置く。
func _place_arrow(on_view: Vector2, view_size: Vector2) -> void:
	var center := view_size * 0.5
	var to_target := on_view - center
	var half := center - Vector2(edge_margin, edge_margin)
	var scale_x := half.x / absf(to_target.x) if not is_zero_approx(to_target.x) else INF
	var scale_y := half.y / absf(to_target.y) if not is_zero_approx(to_target.y) else INF
	var edge := center + to_target * minf(scale_x, scale_y)

	# ゲーム画面（SubViewport）は画面の中央に置かれているので、UILayer 上ではその分ずらす
	var screen_size := screen_arrow.get_viewport().get_visible_rect().size
	var frame_origin := ((screen_size - view_size) * 0.5).round()

	screen_arrow.visible = true
	screen_arrow.position = (frame_origin + edge).round()
	# triangle.png は下（+Y）向きの絵なので、+Y を目的地の方向へ回す
	screen_arrow.rotation = to_target.angle() - PI * 0.5
	var s := 1.0 + sin(_pulse_time * arrow_pulse_speed) * arrow_pulse_scale
	screen_arrow.scale = Vector2(s, s)


func _set_shown(shown: bool) -> void:
	visible = shown
	if screen_arrow and not shown:
		screen_arrow.visible = false


func _is_player_locked() -> bool:
	return player != null and player.has_method("is_control_locked") and player.is_control_locked()
