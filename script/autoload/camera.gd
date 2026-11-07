extends Node

enum CameraState {
	FOLLOW_TARGET,
	BATTLE,
	AVERAGE_CENTER,
	FREE
}

var state: CameraState = CameraState.FOLLOW_TARGET

var new_camera_position: Vector2 = Vector2.ZERO
var cam_smooth: Vector2
var current_target: String = ""

var targets: Dictionary[String, Node2D] = {}

var container: Control
var subviewport: SubViewport
var camera: Camera2D

var map_rect: Rect2 = Rect2(Vector2.ZERO, Vector2.ZERO)

var FOLLOW_SPEED: float = 8.0
var follow_speed: float = 8.0

## 外部アクセスを想定。true でその直後のカメラ移動が瞬間的に切り替わる
var brif_camera: bool = false

var camera_zoom_offset: Vector2 = Vector2.ZERO

func reset() -> void:
	state = CameraState.FOLLOW_TARGET

## エンディングのカメラ演出を 0 秒目の姿勢で止めておく。
## 画面が見え始める前に構図だけ決めておくために使う。start_ending_animation() で続きから再生される。
func prepare_ending_animation() -> void:
	if camera:
		var anim: AnimationPlayer = camera.get_node("AnimationPlayer")
		anim.play("ending_camera_show")
		# update_only = true: 姿勢だけ反映し、0 秒目のメソッド呼び出しや音は鳴らさない
		anim.seek(0.0, true, true)
		anim.pause()

func start_ending_animation() -> void:
	if camera:
		camera.get_node("AnimationPlayer").play("ending_camera_show")

func start_ending_logo_animation() -> void:
	if camera:
		camera.get_node("AnimationPlayer").play("ending_logo_anim")

func set_zoom_value(zoom_value: Vector2, duration: float = 0.5) -> void:
	if camera:
		var tw = create_tween()
		tw.tween_property(self, "camera_zoom_offset", zoom_value,  duration)
	else:
		push_error("Camera2D: Camera node is not set. Please call set_node_data() to set the camera node.")

var _punch_tween: Tween
var _punch_base: Vector2 = Vector2.ONE

## 一瞬だけ amount ぶん寄せて、元の倍率へ duration 秒かけて戻す（パリィの演出など）。
## 戻り先は呼ばれた時点の倍率なので、ステージごとの基本倍率を知らなくてよい。
func punch_zoom(amount: Vector2, duration: float) -> void:
	if _punch_tween and _punch_tween.is_running():
		_punch_tween.kill()
		camera_zoom_offset = _punch_base
	_punch_base = camera_zoom_offset if camera_zoom_offset != Vector2.ZERO else Vector2.ONE
	camera_zoom_offset = _punch_base + amount
	_punch_tween = create_tween()
	_punch_tween.tween_property(self, "camera_zoom_offset", _punch_base, duration)

func set_node_data(_camera: Camera2D, _container: Control, _subviewport: SubViewport) -> void:
	camera = _camera
	container = _container
	subviewport = _subviewport
	if camera:
		camera.enabled = true
		camera.make_current()

func set_do_brief_camera(value: bool) -> void:
	brif_camera = value

func set_state(new_state: CameraState) -> void:
	state = new_state

func reset_target_dictionary() -> void:
	targets.clear()

func add_target(name: String, target: Node2D) -> void:
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

## get_current_position() を持つ対象はそれを使う。持たない対象（像など）は global_position。
func _get_target_position(target: Node2D) -> Vector2:
	if target.has_method("get_current_position"):
		return target.get_current_position()
	return target.global_position

func _get_screen_position(target: Node2D) -> Vector2:
	var viewport = target.get_viewport()
	var target_position: Vector2 = viewport.get_canvas_transform() * target.get_global_transform().origin
	return target_position

func get_current_zoom_value() -> Vector2:
	if camera:
		return camera.zoom
	else:
		push_error("Camera2D: Camera node is not set. Please call set_node_data() to set the camera node.")
		return Vector2.ONE

func _ready() -> void:
	follow_speed = FOLLOW_SPEED

func _process(delta: float) -> void:
	if state == CameraState.FREE:
		return
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
				new_camera_position = _get_target_position(targets[current_target])
			else:
				push_error("Camera2D: Current target '%s' does not exist in targets." % current_target)
		CameraState.AVERAGE_CENTER:
			var total_position: Vector2 = Vector2.ZERO
			for target in targets.values():
				if is_instance_valid(target):
					total_position += _get_target_position(target)
				else:
					push_error("Camera2D: One of the targets is null.")
			new_camera_position = total_position / targets.size()
		CameraState.BATTLE:
			var total_position: Vector2 = Vector2.ZERO
			for target in targets.values():
				if is_instance_valid(target):
					total_position += _get_target_position(target)
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

	# set good zoom value based on targets distance if state is battle state
	var battle_zoom_value: float = 1.0
	if state != CameraState.BATTLE:
		pass
	else:
		var max_distance: float = 400
		var min_distance: float = 50
		if targets.values().size() != 2:
			push_error("Camera2D: BATTLE state requires exactly 2 targets.")
			return
		var distance: float = _get_target_position(targets.values()[0]).distance_to(_get_target_position(targets.values()[1]))
		battle_zoom_value = remap(clamp(distance, min_distance, max_distance), min_distance, max_distance, 1.5, 0.8)

	# set camera zoom
	if camera_zoom_offset == Vector2.ZERO:
		camera_zoom_offset = Vector2.ONE

	camera.zoom = Vector2.ONE * camera_zoom_offset * battle_zoom_value