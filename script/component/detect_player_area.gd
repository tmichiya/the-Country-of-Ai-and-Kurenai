extends Area2D

signal entered()
signal exited()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)

func _on_entered(body: CharacterBody2D) -> void:
	if not body.is_in_group("player"):
		return
	print("Player entered the area.")
	entered.emit()

func _on_exited(body: CharacterBody2D) -> void:
	if not body.is_in_group("player"):
		return
	exited.emit()
