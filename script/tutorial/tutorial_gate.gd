class_name TutorialGate
extends StaticBody2D
## 区画の出口をふさぐ柵。open() で当たり判定を消し、見た目をフェードさせる。

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var visual: CanvasItem = $Visual

var is_open: bool = false


func open() -> void:
	if is_open:
		return
	is_open = true
	collision.set_deferred("disabled", true)
	AudioManager.play_se("bell_1")
	var tw := create_tween()
	tw.tween_property(visual, "modulate:a", 0.0, 0.5)
