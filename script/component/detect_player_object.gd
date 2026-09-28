extends Node2D

signal entered
signal exited

@onready var area2d: Area2D = $Hitbox
@onready var collision_shape: CollisionShape2D = $Hitbox/CollisionShape2D

## 一発屋の制御はこのフラグで行う（monitoring は常時ONのまま）
var _armed: bool = false
## 「落ち着いたら arm する」待ち状態
var _pending_arm: bool = true
## 再アーム要求からの経過物理フレーム数
var _arm_settle: int = 0
## いま重なっているプレイヤーの数（body_entered/body_exited で数える）
var _player_overlaps: int = 0

## 幽霊イベントをやり過ごすのに必要な物理フレーム数。
const ARM_SETTLE_FRAMES := 2

func _ready() -> void:
	area2d.body_entered.connect(_on_entered)
	area2d.body_exited.connect(_on_exited)

func _on_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_overlaps += 1
	if not _armed:
		return
	_armed = false
	_pending_arm = false
	entered.emit()

func _on_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_overlaps = maxi(_player_overlaps - 1, 0)
	exited.emit()

func set_monitoring_active(active: bool) -> void:
	_armed = false
	_pending_arm = active
	_arm_settle = 0

func is_armed() -> bool:
	return _armed

func _physics_process(_delta: float) -> void:
	if not _pending_arm:
		return
	_arm_settle += 1
	if _arm_settle < ARM_SETTLE_FRAMES:
		return
	if _player_overlaps > 0:
		return
	_armed = true
	_pending_arm = false
