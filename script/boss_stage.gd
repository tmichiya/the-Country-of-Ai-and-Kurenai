extends Node2D

@onready var battle_start_area: Area2D = $BattleStartArea

enum StageState {
	WALK_IN,
	PRE_TALK,
	BATTLE,
	POST_TALK,
	WALK_OUT
}

var state: StageState

func reset() -> void:
	state = StageState.WALK_IN

func _on_battle_start_area_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	state = StageState.BATTLE

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	battle_start_area.entered.connect(_on_battle_start_area_entered)

	reset()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
