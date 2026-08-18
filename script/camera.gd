extends Camera2D

enum CameraState {
	FOLLOW_PLAYER,
	BATTLE
}

var state: CameraState = CameraState.FOLLOW_PLAYER

var new_camera_position: Vector2 = Vector2.ZERO
var cam_smooth: Vector2

@export var boss_stage: Node2D
@export var player: Node2D
@export var battle_target: Node2D
@export var container: Control
@export var subviewport: SubViewport
@export var follow_speed: float = 8.0

func reset() -> void:
	state = CameraState.FOLLOW_PLAYER

func _on_battle_started() -> void:
	set_state(CameraState.BATTLE)

func _on_battle_finished(is_win: bool) -> void:
	set_state(CameraState.FOLLOW_PLAYER)

func set_state(new_state: CameraState) -> void:
	state = new_state

func _ready() -> void:
	if player == null:
		push_error("Camera2D: Player node is not assigned.")
	if battle_target == null:
		push_error("Camera2D: Battle target node is not assigned.")

	if boss_stage != null:
		boss_stage.battle_started.connect(_on_battle_started)
		boss_stage.battle_finished.connect(_on_battle_finished)


func _process(delta: float) -> void:
	if player == null:
		return

	match state:
		CameraState.FOLLOW_PLAYER:
			new_camera_position = player.global_position.round() 
		CameraState.BATTLE:
			if battle_target == null:
				push_error("Camera2D: Battle target node is not assigned.")
				state = CameraState.FOLLOW_PLAYER
				return
			
			new_camera_position = (player.global_position + battle_target.global_position) / 2

	# smooth camera
	var t : float = 1.0 - exp(-follow_speed * delta)
	cam_smooth = cam_smooth.lerp(new_camera_position, t)

	var snapped : Vector2 = cam_smooth.round()
	global_position = snapped

	var frac = cam_smooth - snapped
	var scale = float(container.size.x) / float(subviewport.size.x)
	container.position = -frac * scale