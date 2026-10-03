extends Node2D

signal interaction_started
signal interaction_ended
signal interacted

@onready var area: Area2D = $Area2D

func _ready() -> void:
	area.body_entered.connect(_on_area_body_entered)
	area.body_exited.connect(_on_area_body_exited)

func _on_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		interaction_started.emit()

		body.set_interactable(true, self)

func _on_area_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		interaction_ended.emit()

		body.set_interactable(false, self)

func interact() -> void:
	interacted.emit()

func _process(delta: float) -> void:
	pass
