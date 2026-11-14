extends Control	

@onready var label: Label = $Label

@export var target_node: Node2D
@export var target_property: String

func _process(delta: float) -> void:
	if target_node != null and target_property != "":
		label.text = str(target_node.get(target_property))
