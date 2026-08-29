extends Area2D

signal entered()
signal exited()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

## 一発屋の制御はこのフラグで行う（monitoring は常時ONのまま）
var _armed: bool = true

func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)

func _on_entered(body: Node2D) -> void:
	print("DetectPlayerArea: body_entered: %s, _armed: %s, body.is_in_group('player'): %s" % [body.name, _armed, body.is_in_group("player")])
	if not _armed or not body.is_in_group("player"):
		return
	_armed = false          # monitoring は切らない。フラグだけで一回きりにする
	print("Player entered the area.")
	entered.emit()

func _on_exited(body: Node2D) -> void:
	print("DetectPlayerArea: body_exited: %s, _armed: %s, body.is_in_group('player'): %s" % [body.name, _armed, body.is_in_group("player")])
	if not body.is_in_group("player"):
		return
	print("Player exited the area.")
	exited.emit()

## reset_room から呼んで再アームする
func set_monitoring_active(active: bool) -> void:
	print("DetectPlayerArea: set_monitoring_active: %s" % active)
	_armed = active
