extends Node2D

signal body_entered(body: Node)
signal body_exited(body: Node)

@onready var hit_box: Area2D = $Hitbox

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hit_box.body_entered.connect(_on_body_entered)
	hit_box.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	body_entered.emit(body)

func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	body_exited.emit(body)