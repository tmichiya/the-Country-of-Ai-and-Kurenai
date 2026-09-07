extends PanelContainer

@onready var label: Label = $MarginContainer/Label

func set_text(text: String) -> void:
	label.text = text