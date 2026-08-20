extends Node2D

## プレイヤーが Hitbox に入った/出たを通知するだけの単純な検知コンポーネント。
## 「一度だけ」等の制御はここでは持たない（呼び出し側で扱う）。

signal entered
signal exited

@onready var area2d: Area2D = $Hitbox
@onready var collision_shape: CollisionShape2D = $Hitbox/CollisionShape2D

func _ready() -> void:
	area2d.body_entered.connect(_on_entered)
	area2d.body_exited.connect(_on_exited)

func _on_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		entered.emit()

func _on_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		exited.emit()
