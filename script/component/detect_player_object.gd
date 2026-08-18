extends Area2D

signal entered(body: Node)
signal exited(body: Node)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	entered.connect(_on_entered)
	exited.connect(_on_exited)

func _on_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	entered.emit(body)

func _on_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	exited.emit(body)