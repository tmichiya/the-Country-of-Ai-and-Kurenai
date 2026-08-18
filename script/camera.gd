extends Camera2D

enum CameraState {
	FOLLOW_PLAYER,
	BATTLE
}

var state: CameraState = CameraState.FOLLOW_PLAYER

@export var player: Node2D
@export var battle_target: Node2D

func reset() -> void:
	state = CameraState.FOLLOW_PLAYER

func _ready() -> void:
	if player == null:
		push_error("Camera2D: Player node is not assigned.")

func set_state(new_state: CameraState) -> void:
	state = new_state

func _process(delta: float) -> void:
	if player == null:
		return

	match state:
		CameraState.FOLLOW_PLAYER:
			global_position = player.global_position
		CameraState.BATTLE:
			if battle_target == null:
				push_error("Camera2D: Battle target node is not assigned.")
				state = CameraState.FOLLOW_PLAYER
				return
			
			var new_camera_position = (player.global_position + battle_target.global_position) / 2
			global_position = new_camera_position