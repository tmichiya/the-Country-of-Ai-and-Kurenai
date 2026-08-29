extends Node

enum CameraState {
	FOLLOW_TARGET,
	BATTLE,
	AVERAGE_CENTER
}

var state: CameraState = CameraState.FOLLOW_TARGET

var new_camera_position: Vector2 = Vector2.ZERO
var cam_smooth: Vector2
var current_target: String = ""

var targets: Dictionary = {}

var container: Control
var subviewport: SubViewport
var camera: Camera2D

var map_rect: Rect2 = Rect2(Vector2.ZERO, Vector2.ZERO)

var FOLLOW_SPEED: float = 8.0
var follow_speed: float = 8.0

var brif_camera: bool = false

func reset() -> void:
	state = CameraState.FOLLOW_TARGET

func set_zoom_value(zoom_value: Vector2, duration: float = 0.5) -> void:
	if camera:
		var tw = create_tween()
		tw.tween_property(camera, "zoom", zoom_value,  duration)
	else:
		push_error("Camera2D: Camera node is not set. Please call set_node_data() to set the camera node.")

func set_node_data(_camera: Camera2D, _container: Control, _subviewport: SubViewport) -> void:
	camera = _camera
	container = _container
	subviewport = _subviewport
	# このカメラを SubViewport の有効カメラにする。
	# これをしないと SubViewport はワールド原点(0,0)を左上に描画し、
	# カメラ位置を動かしても画面に反映されない（＝プレイヤーが左上に見える原因）。
	if camera:
		camera.enabled = true
		camera.make_current()

func set_state(new_state: CameraState) -> void:
	state = new_state

func reset_target_dictionary() -> void:
	targets.clear()

func add_target(name: String, target: Node2D) -> void:
	print("Adding target: %s" % name)
	if not targets.has(name):
		targets[name] = target
	else:
		push_error("Camera2D: Target with name '%s' already exists." % name)

func set_current_target(name: String) -> void:
	if targets.has(name):
		current_target = name
	else:
		push_error("Camera2D: Target with name '%s' does not exist." % name)

func set_follow_speed(speed: float) -> void:
	follow_speed = speed

func activate_brief_camera() -> void:
	brif_camera = true

func set_offset(offset: Vector2, duration: float = 0.5) -> void:
	if camera:
		var tw = create_tween()
		tw.tween_property(camera, "offset", offset, duration)
	else:
		push_error("Camera2D: Camera node is not set. Please call set_node_data() to set the camera node.")

func _get_screen_position(target: Node2D) -> Vector2:
	var viewport = target.get_viewport()
	var target_position: Vector2 = viewport.get_canvas_transform() * target.get_global_transform().origin
	return target_position

func _ready() -> void:
	follow_speed = FOLLOW_SPEED

func _process(delta: float) -> void:
	if camera == null:
		print("Camera2D: Camera node is not set. Please call set_node_data() to set the camera node.")
		return
	if targets.size() == 0:
		print("Camera2D: No targets assigned. Please add targets using add_target() before running the scene.")
		return
	if container == null:
		print("Camera2D: Container node is not set. Please call set_node_data() to set the container node.")
		return
	if subviewport == null:
		print("Camera2D: SubViewport node is not set. Please call set_node_data() to set the subviewport node.")
		return

	# set new camera position based on state
	match state:
		CameraState.FOLLOW_TARGET:
			if targets.has(current_target):
				new_camera_position = targets[current_target].global_position
			else:
				push_error("Camera2D: Current target '%s' does not exist in targets." % current_target)
		CameraState.AVERAGE_CENTER:
			var total_position: Vector2 = Vector2.ZERO
			for target in targets.values():
				if target != null:
					total_position += target.global_position
				else:
					push_error("Camera2D: One of the targets is null.")
			new_camera_position = total_position / targets.size()

	# clamp pos
	if map_rect.size != Vector2.ZERO:
		var half_screen_size: Vector2 = subviewport.size * 0.5 / camera.zoom
		var max_pos: Vector2 = map_rect.position + map_rect.size * 0.5 - half_screen_size - camera.offset
		var min_pos: Vector2 = map_rect.position - map_rect.size * 0.5 + half_screen_size - camera.offset
		new_camera_position.x = clamp(new_camera_position.x, min_pos.x, max_pos.x)
		new_camera_position.y = clamp(new_camera_position.y, min_pos.y, max_pos.y)

	# move camera smoothly
	if brif_camera:
		cam_smooth = new_camera_position
		brif_camera = false
	else:
		var t : float = 1.0 - exp(-follow_speed * delta)
		cam_smooth = cam_smooth.lerp(new_camera_position, t)

	var snapped_pos : Vector2 = cam_smooth.round()
	camera.global_position = snapped_pos
	# 画面の中央寄せは各ステージ側で CenterContainer をウィンドウサイズに合わせて行う。
	# ここで container の位置を上書きすると描画と入力矩形がズレる（マウスが SubViewport に届かない）ため触らない。
